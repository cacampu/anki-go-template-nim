import std/strutils

## SGFのCプロパティ内で、`@front`/`@back`/`@common`の行によって
## 表面専用・裏面専用・共通のセクションを切り替えるための簡易フォーマット。
##
## - `@front`: 以降の行は表面(showAns前)でのみ表示
## - `@back`:  以降の行は裏面(showAns後)でのみ表示
## - `@common`: 以降の行を共通(常時表示)に戻す
## - マーカーが無い行はデフォルトで共通として扱われる(従来形式と後方互換)

type CommentSection = enum
  Common, FrontOnly, BackOnly

proc render_comment*(text: string, show_ans: bool): string =
  var section = Common
  var lines: seq[string]
  for line in text.splitLines():
    case line.strip()
    of "@front": section = FrontOnly
    of "@back": section = BackOnly
    of "@common": section = Common
    else:
      let visible =
        case section
        of Common: true
        of FrontOnly: not show_ans
        of BackOnly: show_ans
      if visible:
        lines.add(line)
  lines.join("\n")
