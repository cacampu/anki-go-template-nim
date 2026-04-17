#!/usr/bin/env python3
"""
AnkiConnect を使ってノートタイプ (Go Problem) を作成・更新する。
dist/front.html, dist/back.html, dist/style.css を読み込んでテンプレートに設定する。

Usage:
    python scripts/setup_model.py
"""

import json
import urllib.request
from pathlib import Path

ANKI_CONNECT_URL = "http://localhost:8765"
MODEL_NAME = "Go Problem"
DIST_DIR = Path(__file__).parent.parent / "dist"


def ankiconnect(action: str, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params})
    req = urllib.request.Request(ANKI_CONNECT_URL, payload.encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read())
    if data.get("error"):
        raise RuntimeError(f"AnkiConnect error: {data['error']}")
    return data["result"]


def main():
    front = (DIST_DIR / "front.html").read_text(encoding="utf-8")
    back  = (DIST_DIR / "back.html").read_text(encoding="utf-8")
    css   = (DIST_DIR / "style.css").read_text(encoding="utf-8")

    existing_models = ankiconnect("modelNames")

    if MODEL_NAME not in existing_models:
        print(f"Creating model: {MODEL_NAME}")
        ankiconnect(
            "createModel",
            modelName=MODEL_NAME,
            inOrderFields=["ID", "SGF"],
            css=css,
            cardTemplates=[
                {
                    "Name": "Card 1",
                    "Front": front,
                    "Back": back,
                }
            ],
        )
        print("Done.")
    else:
        print(f"Model '{MODEL_NAME}' already exists. Updating templates and styling...")
        ankiconnect(
            "updateModelTemplates",
            model={
                "name": MODEL_NAME,
                "templates": {
                    "Card 1": {
                        "Front": front,
                        "Back": back,
                    }
                },
            },
        )
        ankiconnect(
            "updateModelStyling",
            model={
                "name": MODEL_NAME,
                "css": css,
            },
        )
        print("Done.")


if __name__ == "__main__":
    main()
