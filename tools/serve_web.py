"""build/web/ をローカル確認する簡易サーバー。
使い方: python tools/serve_web.py  ->  http://127.0.0.1:8099
"""
import http.server
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)


if __name__ == "__main__":
    print(f"serving {ROOT}  ->  http://127.0.0.1:8099")
    http.server.HTTPServer(("127.0.0.1", 8099), Handler).serve_forever()
