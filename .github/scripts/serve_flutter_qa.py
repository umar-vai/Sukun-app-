#!/usr/bin/env python3
"""Serve a compiled Flutter Web PR build locally for isolated screenshot QA.

This is never deployed. Only localhost is bound; history-mode UI routes
fall back to the packaged index.html without exposing another website.
"""

import http.server
from pathlib import Path
import sys
from urllib.parse import urlsplit


class FlutterQaHandler(http.server.SimpleHTTPRequestHandler):
    root: Path

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.root), **kwargs)

    def do_GET(self):
        requested = urlsplit(self.path).path
        target = self.root.joinpath(requested.lstrip("/"))
        if not target.exists() and not Path(requested).suffix:
            self.path = "/Sukun-app-/index.html"
        return super().do_GET()


if __name__ == "__main__":
    FlutterQaHandler.root = Path(sys.argv[1]).resolve()
    port = int(sys.argv[2])
    http.server.ThreadingHTTPServer(("127.0.0.1", port), FlutterQaHandler).serve_forever()
