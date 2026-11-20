"""Serve the exported Godot build on this computer."""

import argparse
import errno
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import webbrowser


OUTPUT = Path(__file__).resolve().parents[2] / "liminal-godot-web"


class WebFiles(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}


def serve(port, open_browser):
    if not (OUTPUT / "index.html").is_file():
        raise SystemExit("找不到网页构建。请先运行 tools/export_web.py。")
    handler = partial(WebFiles, directory=str(OUTPUT))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    except OSError as error:
        if error.errno != errno.EADDRINUSE and getattr(error, "winerror", 0) != 10048:
            raise
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    with server:
        address = f"http://127.0.0.1:{server.server_port}/"
        print(address, flush=True)
        if open_browser:
            webbrowser.open(address)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    serve(args.port, not args.no_open)
