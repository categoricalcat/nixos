import atexit
import functools
import http.server
import os
import shutil
import signal
import sys
import urllib.parse

site_dir, closure_json = sys.argv[1], sys.argv[2]
# The shell EXIT trap dies at exec; the interpreter owns cleanup from here on.
atexit.register(os.unlink, closure_json)
# SIGTERM (kill, systemd stop) must unwind through atexit so background
# launches clean up too; SIGINT reaches the KeyboardInterrupt catch below.
signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(0))


class Handler(http.server.SimpleHTTPRequestHandler):
    # The default translate_path (unquote + normpath + segment filter) is
    # traversal-safe; never override it.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".json": "application/json",
        ".wasm": "application/wasm",
    }

    def do_GET(self):
        if urllib.parse.urlparse(self.path).path == "/closure.json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            with open(closure_json, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
        else:
            super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


server = http.server.ThreadingHTTPServer(
    ("127.0.0.1", 8138), functools.partial(Handler, directory=site_dir)
)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
