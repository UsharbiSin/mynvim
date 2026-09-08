"""Validate local Markdown links in the repository documentation."""

from pathlib import Path
import re
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md"))]
LINK = re.compile(r"!?\[[^]]*]\(([^)]+)\)")


def local_target(raw: str) -> str | None:
    target = raw.strip().strip("<>")
    if not target or target.startswith(("#", "http://", "https://", "mailto:")):
        return None
    return unquote(target.split("#", 1)[0])


missing: list[str] = []
checked = 0
for document in DOCUMENTS:
    for match in LINK.finditer(document.read_text(encoding="utf-8")):
        target = local_target(match.group(1))
        if target is None:
            continue
        checked += 1
        resolved = (document.parent / target).resolve()
        if not resolved.exists():
            missing.append(f"{document.relative_to(ROOT)} -> {target}")

if missing:
    raise SystemExit("Missing local Markdown links:\n" + "\n".join(missing))

print(f"PASS: {checked} local Markdown links across {len(DOCUMENTS)} documents")
