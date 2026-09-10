"""Safely export a SQL result grid to CSV or a minimal XLSX workbook."""

from __future__ import annotations

import csv
import json
import os
from pathlib import Path
import sys
import tempfile
import zipfile
from xml.sax.saxutils import escape

if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


def valid_xml_text(value: object) -> str:
    text = "" if value is None else str(value)
    return "".join(
        char for char in text
        if ord(char) in (9, 10, 13) or 0x20 <= ord(char) <= 0xD7FF
        or 0xE000 <= ord(char) <= 0xFFFD
    )


def column_name(index: int) -> str:
    result = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        result = chr(65 + remainder) + result
    return result


def atomic_target(path: Path) -> tuple[Path, int]:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    return Path(name), descriptor


def export_csv(path: Path, columns: list[str], rows: list[list[object]]) -> None:
    temporary, descriptor = atomic_target(path)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.writer(stream, lineterminator="\r\n")
            writer.writerow(columns)
            writer.writerows(rows)
        os.replace(temporary, path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def worksheet_xml(columns: list[str], rows: list[list[object]]) -> str:
    values = [columns, *rows]
    xml_rows = []
    for row_index, row in enumerate(values, 1):
        cells = []
        for column_index, value in enumerate(row, 1):
            text = escape(valid_xml_text(value)[:32767])
            reference = f"{column_name(column_index)}{row_index}"
            cells.append(f'<c r="{reference}" t="inlineStr"><is><t xml:space="preserve">{text}</t></is></c>')
        xml_rows.append(f'<row r="{row_index}">{"".join(cells)}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f'<sheetData>{"".join(xml_rows)}</sheetData></worksheet>'
    )


def export_xlsx(path: Path, columns: list[str], rows: list[list[object]]) -> None:
    if len(columns) > 16384 or len(rows) >= 1048576:
        raise ValueError("result exceeds the XLSX row or column limit")
    temporary, descriptor = atomic_target(path)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("[Content_Types].xml", (
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                '<Default Extension="xml" ContentType="application/xml"/>'
                '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
                '</Types>'
            ))
            archive.writestr("_rels/.rels", (
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
                '</Relationships>'
            ))
            archive.writestr("xl/workbook.xml", (
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
                'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                '<sheets><sheet name="查询结果" sheetId="1" r:id="rId1"/></sheets></workbook>'
            ))
            archive.writestr("xl/_rels/workbook.xml.rels", (
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
                'Target="worksheets/sheet1.xml"/></Relationships>'
            ))
            archive.writestr("xl/worksheets/sheet1.xml", worksheet_xml(columns, rows))
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None:
                raise ValueError("generated XLSX ZIP is invalid")
        os.replace(temporary, path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def main() -> None:
    payload = json.load(sys.stdin)
    path = Path(payload["path"]).expanduser().resolve()
    columns = [str(value) for value in payload.get("columns", [])]
    rows = payload.get("rows", [])
    kind = payload["format"].lower()
    if not columns:
        raise ValueError("result has no columns")
    if any(len(row) != len(columns) for row in rows):
        raise ValueError("result rows do not match the columns")
    if kind == "csv":
        export_csv(path, columns, rows)
    elif kind == "xlsx":
        export_xlsx(path, columns, rows)
    else:
        raise ValueError(f"unsupported export format: {kind}")
    print(json.dumps({"path": str(path), "rows": len(rows), "format": kind}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
