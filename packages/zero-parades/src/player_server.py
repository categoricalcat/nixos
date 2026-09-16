#!/usr/bin/env python3
"""
player_server.py — On-demand voiceover streaming server and minimal web player
for Zero Parades: For Dead Spies.
"""

import argparse
import csv
import functools
import json
import logging
import os
import sys
import threading
import urllib.parse
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

try:
    import fsb5
except ImportError:
    sys.exit(
        "Error: fsb5 is required for audio decoding. Install with: pip install fsb5"
    )

logger = logging.getLogger("zero_parades_player")

DEFAULT_STEAM_DIR = Path("/home/yi/.local/share/Steam/steamapps/common/Zero Parades")
DEFAULT_BANKS_DIR = DEFAULT_STEAM_DIR / "ZeroParades_Data/StreamingAssets/SoundBanks"
DEFAULT_CSV_PATHS = [
    Path("./zero_parades_dialogue_en.csv"),
    Path("./output/zero_parades_dialogue_en.csv"),
    Path("/mnt/smb/the.files/nixos/tools/zero-parades/output/zero_parades_dialogue_en.csv"),
    Path.home() / ".cache/zero-parades/zero_parades_dialogue_en.csv",
]

FAVICON_SVG = (
    b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">'
    b'<rect width="32" height="32" rx="6" fill="#1a1d24"/>'
    b'<polygon points="12,9 24,16 12,23" fill="#e5a93b"/>'
    b'</svg>'
)

# Global application state
STATE = {
    "lines": [],
    "speakers": [],
    "speaker_counts": {},
    "speaker_voiced_counts": {},
    "banks_dir": None,
    "csv_path": None,
    "available_banks": set(),
    "voiced_card_keys": set(),
    "web_dir": None,
}

# Cache for opened and parsed FSB5 objects: {flow_id: fsb5.FSB5}
FSB_CACHE = {}
FSB_CACHE_LOCK = threading.Lock()

# Cache for rendered Ogg Vorbis byte payloads: {(flow_id, card_id): bytes}
AUDIO_BYTES_CACHE = {}
AUDIO_CACHE_LOCK = threading.Lock()
MAX_AUDIO_CACHE_ENTRIES = 500


def find_default_csv(user_path: str | None = None) -> Path:
    """Resolve the dialogue CSV file path."""
    if user_path:
        p = Path(user_path)
        if p.is_file():
            return p
        raise FileNotFoundError(f"Provided dialogue file not found: {user_path}")

    for candidate in DEFAULT_CSV_PATHS:
        if candidate.is_file():
            return candidate.resolve()

    raise FileNotFoundError(
        "Could not find zero_parades_dialogue_en.csv in default locations. "
        "Please provide path using --dialogue-file."
    )


def find_default_banks(user_path: str | None = None) -> Path:
    """Resolve the SoundBanks directory path."""
    if user_path:
        p = Path(user_path)
        if p.is_dir():
            return p
        raise FileNotFoundError(f"Provided SoundBanks directory not found: {user_path}")

    if DEFAULT_BANKS_DIR.is_dir():
        return DEFAULT_BANKS_DIR.resolve()

    raise FileNotFoundError(
        f"Could not find SoundBanks directory at {DEFAULT_BANKS_DIR}. "
        "Please provide path using --banks-dir."
    )


def load_dialogue_data(csv_path: Path, banks_dir: Path):
    """Load and index dialogue CSV lines and exact audio sample presence into memory."""
    logger.info("Loading dialogue lines from %s...", csv_path)
    lines = []
    speaker_counts = {}
    speaker_voiced_counts = {}

    # Scan available bank flow_ids and all exact (flow_id, card_id) sample entries
    available_banks = set()
    voiced_card_keys = set()
    if banks_dir.is_dir():
        for bnk in sorted(banks_dir.glob("BNK_VO_*.bank")):
            flow_id = bnk.stem.replace("BNK_VO_", "")
            available_banks.add(flow_id)
            try:
                with open(bnk, "rb") as f:
                    data = f.read()
                idx = data.find(b"FSB5")
                if idx != -1:
                    fsb = fsb5.FSB5(data[idx:])
                    for s in fsb.samples:
                        c_id = s.name.split("-")[0]
                        voiced_card_keys.add((flow_id, c_id))
            except Exception as e:
                logger.debug("Failed reading samples in %s: %s", bnk.name, e)

    logger.info("Indexed %d voiceover bank files and %d unique voiced card samples in %s",
                len(available_banks), len(voiced_card_keys), banks_dir)

    with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            flow_id = row.get("flow_id", "")
            card_id = row.get("card_id", "")
            has_vo = (flow_id, card_id) in voiced_card_keys
            row["has_vo"] = has_vo
            row["has_bank"] = has_vo  # backward compatibility for frontend
            lines.append(row)
            spk = row.get("speaker", "unknown")
            speaker_counts[spk] = speaker_counts.get(spk, 0) + 1
            if has_vo:
                speaker_voiced_counts[spk] = speaker_voiced_counts.get(spk, 0) + 1

    # Sort dialogue lines so voiced dialogue lines come first, then flows, then id
    lines.sort(key=lambda x: (not x.get("has_vo", False), x.get("chunk_type") != "flow", int(x.get("id", 0) or 0)))

    sorted_speakers = sorted(speaker_counts.items(), key=lambda x: (speaker_voiced_counts.get(x[0], 0), x[1]), reverse=True)

    STATE["lines"] = lines
    STATE["speakers"] = [
        {"name": s, "count": c, "voiced_count": speaker_voiced_counts.get(s, 0)}
        for s, c in sorted_speakers
    ]
    STATE["speaker_counts"] = speaker_counts
    STATE["speaker_voiced_counts"] = speaker_voiced_counts
    STATE["banks_dir"] = banks_dir
    STATE["csv_path"] = csv_path
    STATE["available_banks"] = available_banks
    STATE["voiced_card_keys"] = voiced_card_keys

    voiced_count = sum(1 for l in lines if l.get("has_vo"))
    logger.info("Loaded %d dialogue lines (%d voiced, %.1f%%) across %d unique speakers.",
                len(lines), voiced_count, (voiced_count / len(lines) * 100) if lines else 0, len(sorted_speakers))


def extract_audio_sample(flow_id: str, card_id: str) -> bytes | None:
    """Extract Ogg Vorbis bytes for a given flow and card on-the-fly."""
    cache_key = (flow_id, card_id)
    with AUDIO_CACHE_LOCK:
        if cache_key in AUDIO_BYTES_CACHE:
            return AUDIO_BYTES_CACHE[cache_key]

    banks_dir = STATE["banks_dir"]
    bank_path = banks_dir / f"BNK_VO_{flow_id}.bank"
    if not bank_path.is_file():
        return None

    # Load or retrieve cached FSB5 object
    with FSB_CACHE_LOCK:
        fsb = FSB_CACHE.get(flow_id)
        if fsb is None:
            try:
                with open(bank_path, "rb") as f:
                    data = f.read()
                idx = data.find(b"FSB5")
                if idx == -1:
                    logger.warning("No FSB5 magic in bank: %s", bank_path)
                    return None
                fsb = fsb5.FSB5(data[idx:])
                if len(FSB_CACHE) > 50:
                    FSB_CACHE.pop(next(iter(FSB_CACHE)))
                FSB_CACHE[flow_id] = fsb
            except Exception as e:
                logger.warning("Failed parsing bank %s: %s", bank_path.name, e)
                return None

    # Find matching sample
    target_names = [
        f"{card_id}-dialog_lines",
        f"{card_id}-alternative1",
        f"{card_id}-alternative2",
        f"{card_id}-alternative3",
        card_id,
    ]

    matched_sample = None
    for sample in fsb.samples:
        if sample.name in target_names:
            matched_sample = sample
            break

    if not matched_sample:
        # Fallback: check prefix
        for sample in fsb.samples:
            if sample.name.startswith(card_id):
                matched_sample = sample
                break

    if not matched_sample:
        return None

    try:
        rebuilt = fsb.rebuild_sample(matched_sample)
        # fsb5 rebuild_sample returns memoryview or object with .data
        audio_bytes = bytes(rebuilt.data if hasattr(rebuilt, "data") else rebuilt)

        with AUDIO_CACHE_LOCK:
            if len(AUDIO_BYTES_CACHE) >= MAX_AUDIO_CACHE_ENTRIES:
                AUDIO_BYTES_CACHE.pop(next(iter(AUDIO_BYTES_CACHE)))
            AUDIO_BYTES_CACHE[cache_key] = audio_bytes

        return audio_bytes
    except Exception as e:
        logger.warning("Failed rebuilding sample %s in %s: %s",
                       matched_sample.name, bank_path.name, e)
        return None


class PlayerRequestHandler(SimpleHTTPRequestHandler):
    """HTTP Request Handler for Zero Parades Player API and static assets."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATE["web_dir"]), **kwargs)

    def log_message(self, format, *args):
        # Silence static asset logs, keep API logs
        if len(args) > 0 and str(args[0]).startswith("GET /api/"):
            logger.debug("%s - - [%s] %s", self.client_address[0], self.log_date_time_string(), format % args)

    def do_HEAD(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/favicon.ico":
            self.send_response(200)
            self.send_header("Content-Type", "image/svg+xml")
            self.send_header("Content-Length", str(len(FAVICON_SVG)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.end_headers()
        elif path == "/api/audio":
            self.handle_api_audio(query, head_only=True)
        elif path in ("/api/status", "/api/speakers", "/api/lines"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
        else:
            super().do_HEAD()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/favicon.ico":
            self.send_response(200)
            self.send_header("Content-Type", "image/svg+xml")
            self.send_header("Content-Length", str(len(FAVICON_SVG)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.end_headers()
            self.wfile.write(FAVICON_SVG)
        elif path == "/api/status":
            self.handle_api_status()
        elif path == "/api/speakers":
            self.handle_api_speakers()
        elif path == "/api/lines":
            self.handle_api_lines(query)
        elif path == "/api/audio":
            self.handle_api_audio(query)
        else:
            # Serve static files from web/
            super().do_GET()

    def handle_api_status(self):
        voiced_count = sum(1 for l in STATE["lines"] if l.get("has_vo"))
        payload = {
            "total_lines": len(STATE["lines"]),
            "voiced_lines": voiced_count,
            "speakers_count": len(STATE["speakers"]),
            "soundbanks_available": len(STATE["available_banks"]),
            "total_audio_samples": len(STATE["voiced_card_keys"]),
            "csv_path": str(STATE["csv_path"]),
            "banks_dir": str(STATE["banks_dir"]),
        }
        self.send_json(payload)

    def handle_api_speakers(self):
        self.send_json(STATE["speakers"])

    def handle_api_lines(self, query: dict):
        q = (query.get("q", [""])[0]).strip().lower()
        speaker = (query.get("speaker", [""])[0]).strip().lower()
        vo_only_param = query.get("vo_only", ["1"])[0].strip()
        vo_only = vo_only_param in ("1", "true", "yes")
        page = int(query.get("page", ["0"])[0])
        limit = min(int(query.get("limit", ["50"])[0]), 200)

        all_lines = STATE["lines"]
        filtered = []

        for item in all_lines:
            if vo_only and not item.get("has_vo", False):
                continue
            if speaker and item.get("speaker", "").lower() != speaker:
                continue
            if q:
                text_match = q in item.get("text", "").lower()
                speaker_match = q in item.get("speaker", "").lower()
                card_match = q in item.get("card_id", "").lower()
                if not (text_match or speaker_match or card_match):
                    continue
            filtered.append(item)

        total_matches = len(filtered)
        start = page * limit
        end = start + limit
        page_items = filtered[start:end]

        response = {
            "total": total_matches,
            "page": page,
            "limit": limit,
            "pages": (total_matches + limit - 1) // limit if limit else 1,
            "items": page_items,
        }
        self.send_json(response)

    def handle_api_audio(self, query: dict, head_only: bool = False):
        flow_id = (query.get("flow", [""])[0]).strip()
        card_id = (query.get("card", [""])[0]).strip()

        if not flow_id or not card_id:
            self.send_error(400, "Missing required query parameters 'flow' and 'card'")
            return

        audio_bytes = extract_audio_sample(flow_id, card_id)
        if not audio_bytes:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            if not head_only:
                self.wfile.write(json.dumps({
                    "error": f"Voiceover audio not found for card '{card_id}' in flow '{flow_id}'"
                }).encode("utf-8"))
            return

        # Check for HTTP Range requests from browser audio players
        range_header = self.headers.get("Range")
        if range_header and range_header.startswith("bytes="):
            try:
                ranges = range_header.replace("bytes=", "").split("-")
                start = int(ranges[0]) if ranges[0] else 0
                end = int(ranges[1]) if ranges[1] else len(audio_bytes) - 1
                end = min(end, len(audio_bytes) - 1)
                chunk = audio_bytes[start:end + 1]
                self.send_response(206)
                self.send_header("Content-Type", "audio/ogg")
                self.send_header("Content-Range", f"bytes {start}-{end}/{len(audio_bytes)}")
                self.send_header("Content-Length", str(len(chunk)))
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                if not head_only:
                    self.wfile.write(chunk)
                return
            except Exception:
                pass

        self.send_response(200)
        self.send_header("Content-Type", "audio/ogg")
        self.send_header("Content-Length", str(len(audio_bytes)))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "public, max-age=86400")
        self.end_headers()
        if not head_only:
            self.wfile.write(audio_bytes)

    def send_json(self, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def run_server(host: str, port: int, no_browser: bool):
    """Start the multi-threaded HTTP server."""
    server_address = (host, port)
    httpd = ThreadingHTTPServer(server_address, PlayerRequestHandler)
    url = f"http://{host}:{port}"
    logger.info("Zero Parades Voiceover Player running at: %s", url)

    if not no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("\nShutting down server...")
    finally:
        httpd.server_close()


def main():
    parser = argparse.ArgumentParser(
        description="Zero Parades Voiceover Player Server (On-Demand Audio Streaming)"
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Host interface to bind to (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="Port to listen on (default: 8080)",
    )
    parser.add_argument(
        "--dialogue-file",
        help="Path to extracted zero_parades_dialogue_en.csv (auto-detected if omitted)",
    )
    parser.add_argument(
        "--banks-dir",
        help="Path to Steam SoundBanks directory (auto-detected if omitted)",
    )
    parser.add_argument(
        "--no-browser",
        action="store_true",
        help="Do not open the browser automatically on startup",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="[%(asctime)s] %(levelname)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    csv_path = find_default_csv(args.dialogue_file)
    banks_dir = find_default_banks(args.banks_dir)
    web_dir = Path(__file__).resolve().parent / "web"

    STATE["web_dir"] = web_dir

    load_dialogue_data(csv_path, banks_dir)
    run_server(args.host, args.port, args.no_browser)


if __name__ == "__main__":
    main()
