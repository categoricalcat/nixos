#!/usr/bin/env python3
"""
extract_dialogue.py — Extract all original English dialogue text from Zero Parades.
"""

import argparse
import csv
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
import sys

try:
    import UnityPy
except ImportError:
    sys.exit(
        "Error: UnityPy is required. Install with: pip install UnityPy"
    )

logger = logging.getLogger("zero_parades_extractor")

DEFAULT_BUNDLE_DIR = Path(
    "/home/yi/.local/share/Steam/steamapps/common/Zero Parades/"
    "ZeroParades_Data/StreamingAssets/aa/StandaloneWindows64"
)

CHUNK_TYPE_MAP = {
    "Chunk-flow": "flow",
    "Chunk-bark-flow": "bark",
    "Chunk-dramatic-encounter": "dramatic_encounter",
    "Chunk-orb-flow": "thought_orb",
    "Chunk-process-thought-flow": "thought_process",
}


def find_bundle(bundle_arg: str | None = None) -> Path:
    """Find the dialogue asset bundle."""
    if bundle_arg:
        p = Path(bundle_arg)
        if p.is_file():
            return p
        raise FileNotFoundError(f"Bundle not found at provided path: {bundle_arg}")

    if DEFAULT_BUNDLE_DIR.exists():
        candidates = list(DEFAULT_BUNDLE_DIR.glob("g5ibkj7vdwf2g67g_assets_all_*.bundle"))
        if candidates:
            return candidates[0]

    raise FileNotFoundError(
        f"Could not locate g5ibkj7vdwf2g67g_assets_all_*.bundle in {DEFAULT_BUNDLE_DIR}. "
        "Please provide the path using --bundle."
    )


def determine_chunk_type(chunk_name: str) -> str:
    """Classify chunk type based on its filename prefix."""
    for prefix, ctype in CHUNK_TYPE_MAP.items():
        if chunk_name.startswith(prefix):
            return ctype
    return "other"


def extract_cards_from_chunk(chunk_name: str, chunk_type: str, typetree: dict) -> list[dict]:
    """Extract all dialogue cards from a single chunk's typetree."""
    ref_ids = typetree.get("references", {}).get("RefIds", [])
    if not ref_ids:
        return []

    ref_map = {
        r["rid"]: r
        for r in ref_ids
        if isinstance(r, dict) and "rid" in r
    }

    results = []

    for r in ref_ids:
        type_info = r.get("type", {})
        cls_name = type_info.get("class", "")
        cdata = r.get("data", {})
        if not isinstance(cdata, dict):
            continue

        is_card = "Card" in cls_name or "m_cardId" in cdata
        if not is_card:
            continue

        m_card_data = cdata.get("m_cardData", {})
        if not isinstance(m_card_data, dict):
            continue

        keys = m_card_data.get("m_keys", [])
        values = m_card_data.get("m_values", [])

        props = {}
        for k, v in zip(keys, values):
            rid = v.get("rid") if isinstance(v, dict) else None
            if rid is not None and rid in ref_map:
                target_data = ref_map[rid].get("data", {})
                props[k] = target_data.get("m_value")

        dialog_lines = props.get("dialog_lines")
        if not dialog_lines or not isinstance(dialog_lines, str):
            continue

        text = dialog_lines.strip()
        if not text:
            continue

        speaker = props.get("character_short_name") or "narrator"
        card_id = cdata.get("m_cardId") or ""
        flow_id = cdata.get("m_flowId") or ""
        card_type = cdata.get("m_cardType") or cls_name

        threshold = cdata.get("m_threshold")
        if threshold is None or threshold < 0:
            threshold = ""

        alternatives = []
        for alt_idx in range(1, 10):
            alt_key = f"alternative{alt_idx}"
            alt_val = props.get(alt_key)
            if alt_val and isinstance(alt_val, str) and alt_val.strip():
                alternatives.append(alt_val.strip())

        results.append({
            "chunk_name": chunk_name,
            "chunk_type": chunk_type,
            "flow_id": flow_id,
            "card_id": card_id,
            "card_type": card_type,
            "card_class": cls_name,
            "speaker": speaker,
            "text": text,
            "threshold": threshold,
            "alternatives": alternatives,
        })

    return results


def run_extraction(bundle_path: Path, output_dir: Path, output_format: str) -> None:
    """Execute the extraction and save CSV and/or JSON outputs."""
    logger.info("Loading asset bundle: %s", bundle_path)
    env = UnityPy.load(str(bundle_path))

    chunk_asset_paths = [
        k for k in env.container.keys()
        if "Assets/FELDRuntime/Scriptables/Main/Chunks/" in k
    ]
    chunk_asset_paths.sort()

    logger.info("Found %d chunk assets in bundle.", len(chunk_asset_paths))
    if not chunk_asset_paths:
        logger.error("No Chunk assets found in container!")
        return

    output_dir.mkdir(parents=True, exist_ok=True)

    all_records = []
    speaker_counts = {}
    chunk_type_counts = {}

    for idx, asset_path in enumerate(chunk_asset_paths, 1):
        chunk_filename = Path(asset_path).stem
        chunk_type = determine_chunk_type(chunk_filename)
        chunk_type_counts[chunk_type] = chunk_type_counts.get(chunk_type, 0) + 1

        try:
            typetree = env.container[asset_path].read_typetree()
            records = extract_cards_from_chunk(chunk_filename, chunk_type, typetree)
            for r in records:
                all_records.append(r)
                spk = r["speaker"]
                speaker_counts[spk] = speaker_counts.get(spk, 0) + 1
        except Exception as e:
            logger.warning("Failed to extract %s: %s", chunk_filename, e)

        if idx % 50 == 0 or idx == len(chunk_asset_paths):
            logger.info("Processed %d/%d chunks... (%d lines extracted so far)",
                        idx, len(chunk_asset_paths), len(all_records))

    logger.info("Extraction complete! Total dialogue lines: %d", len(all_records))
    logger.info("Unique speakers: %d", len(speaker_counts))

    if output_format in ("both", "csv"):
        csv_path = output_dir / "zero_parades_dialogue_en.csv"
        logger.info("Writing CSV to %s...", csv_path)
        fieldnames = [
            "id",
            "chunk_name",
            "chunk_type",
            "flow_id",
            "card_id",
            "card_type",
            "card_class",
            "speaker",
            "text",
            "threshold",
            "alternatives",
        ]
        with open(csv_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for line_id, rec in enumerate(all_records, 1):
                row = {
                    "id": line_id,
                    "chunk_name": rec["chunk_name"],
                    "chunk_type": rec["chunk_type"],
                    "flow_id": rec["flow_id"],
                    "card_id": rec["card_id"],
                    "card_type": rec["card_type"],
                    "card_class": rec["card_class"],
                    "speaker": rec["speaker"],
                    "text": rec["text"],
                    "threshold": rec["threshold"],
                    "alternatives": " | ".join(rec["alternatives"]) if rec["alternatives"] else "",
                }
                writer.writerow(row)
        logger.info("CSV export successful: %s (%d lines)", csv_path, len(all_records))

    if output_format in ("both", "json"):
        json_path = output_dir / "zero_parades_dialogue_en.json"
        logger.info("Writing JSON to %s...", json_path)
        payload = {
            "metadata": {
                "game": "Zero Parades: For Dead Spies",
                "extracted_at": datetime.now(timezone.utc).isoformat(),
                "source_bundle": str(bundle_path),
                "total_chunks": len(chunk_asset_paths),
                "chunk_types": chunk_type_counts,
                "total_dialogue_lines": len(all_records),
                "unique_speakers_count": len(speaker_counts),
                "speakers": speaker_counts,
            },
            "dialogue": all_records,
        }
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
        logger.info("JSON export successful: %s", json_path)


def main():
    parser = argparse.ArgumentParser(
        description="Extract all original English dialogue text from Zero Parades."
    )
    parser.add_argument(
        "--bundle",
        help="Path to g5ibkj7vdwf2g67g_assets_all_*.bundle (auto-detected if omitted)",
    )
    parser.add_argument(
        "--output-dir",
        default="./output",
        help="Directory to save output files (default: ./output)",
    )
    parser.add_argument(
        "--format",
        choices=["both", "csv", "json"],
        default="both",
        help="Output format: csv, json, or both (default: both)",
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

    bundle_path = find_bundle(args.bundle)
    output_dir = Path(args.output_dir).resolve()
    run_extraction(bundle_path, output_dir, args.format)


if __name__ == "__main__":
    main()
