#!/usr/bin/env python3
"""
sgf/ ディレクトリを再帰的に走査し、AnkiConnect を使ってカードを追加する。
- デッキ構造: sgf/ 以下のディレクトリ階層をそのまま Anki のデッキ階層に対応させる
  例: sgf/碁経衆妙/碁経衆妙_3_劫之部/QJZM3-007.sgf
      → デッキ: 碁経衆妙::碁経衆妙_3_劫之部
      → ID フィールド: 碁経衆妙/碁経衆妙_3_劫之部/QJZM3-007
- 同じ ID のカードが既に存在する場合はスキップ

Usage:
    python scripts/import_cards.py [--dry-run]
"""

import json
import sys
import urllib.request
from pathlib import Path

ANKI_CONNECT_URL = "http://localhost:8765"
MODEL_NAME = "InteractiveGoCard"
SGF_DIR = Path(__file__).parent.parent / "sgf"
DRY_RUN = "--dry-run" in sys.argv


def ankiconnect(action: str, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params})
    req = urllib.request.Request(ANKI_CONNECT_URL, payload.encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read())
    if data.get("error"):
        raise RuntimeError(f"AnkiConnect error: {data['error']}")
    return data["result"]


def find_sgf_files():
    return sorted(SGF_DIR.rglob("*.sgf"))


def file_to_deck(path: Path) -> str:
    """sgf/A/B/file.sgf → 'A::B'"""
    parts = path.relative_to(SGF_DIR).parts[:-1]  # ファイル名を除くディレクトリ部分
    return "::".join(parts)


def file_to_id(path: Path) -> str:
    """sgf/A/B/file.sgf → 'file' (ファイル名のみ、拡張子なし)"""
    return path.stem


def main():
    files = find_sgf_files()
    if not files:
        print(f"SGF files not found in {SGF_DIR}")
        return

    print(f"Found {len(files)} SGF files.")
    if DRY_RUN:
        print("[DRY RUN] No cards will be added.\n")

    # デッキ単位にファイルをグループ化
    from collections import defaultdict
    deck_files: dict[str, list[Path]] = defaultdict(list)
    for path in files:
        deck_files[file_to_deck(path)].append(path)

    added = 0
    skipped = 0
    errors = 0

    for deck, paths in sorted(deck_files.items()):
        # デッキ作成 (既存の場合は何もしない)
        if not DRY_RUN:
            ankiconnect("createDeck", deck=deck)

        # デッキ内の既存 ID を一括取得
        existing_ids: set[str] = set()
        result = ankiconnect("findNotes", query=f"deck:\"{deck}\"")
        if result:
            note_infos = ankiconnect("notesInfo", notes=result)
            existing_ids = {n["fields"]["ID"]["value"] for n in note_infos}

        notes = []
        for path in sorted(paths):
            card_id = file_to_id(path)
            if card_id in existing_ids:
                print(f"  SKIP  {card_id}")
                skipped += 1
                continue
            notes.append({
                "deckName": deck,
                "modelName": MODEL_NAME,
                "fields": {"ID": card_id, "SGF": path.read_text(encoding="utf-8")},
                "options": {"allowDuplicate": False, "duplicateScope": "deck"},
            })

        if not notes:
            continue

        print(f"  ADD {len(notes)} notes  →  {deck}")
        if DRY_RUN:
            added += len(notes)
            continue

        results = ankiconnect("addNotes", notes=notes)
        ok  = sum(1 for r in results if r is not None)
        err = sum(1 for r in results if r is None)
        added  += ok
        errors += err
        if err:
            print(f"    WARNING: {err} note(s) failed in {deck}")

    print(f"\nDone. added={added}, skipped={skipped}, errors={errors}")


if __name__ == "__main__":
    main()
