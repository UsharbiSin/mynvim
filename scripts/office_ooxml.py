#!/usr/bin/env python3
"""Inspect and minimally patch DOCX/XLSX files for the Neovim Office UI."""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import difflib
import html
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import zipfile
from xml.etree import ElementTree as ET


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
S = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_R = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"s": S, "r": R}
PARAGRAPH = re.compile(r"<w:p(?:\s[^>]*)?>.*?</w:p>", re.S)
TEXT = re.compile(r"(<w:t(?:\s[^>]*)?>)(.*?)(</w:t>)", re.S)
CELL_PATTERN = r"(<c\b[^>]*\br=(?:\"%s\"|'%s')[^>]*>)(.*?)(</c>)"


def read_json(path: str) -> object:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False))


def xml_text(value: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", value))


def escape_text(value: str) -> str:
    value = html.escape(value, quote=False)
    if value.startswith(" ") or value.endswith(" "):
        value = value.replace(" ", "&#32;")
    return value


def clone_zip(source: Path, target: Path, replacements: dict[str, bytes]) -> None:
    with zipfile.ZipFile(source, "r") as incoming, zipfile.ZipFile(target, "w") as outgoing:
        outgoing.comment = incoming.comment
        for info in incoming.infolist():
            data = replacements.get(info.filename, incoming.read(info.filename))
            outgoing.writestr(copy.copy(info), data)


def validate(path: Path, kind: str, changed: list[str]) -> None:
    required = {
        "docx": ["[Content_Types].xml", "_rels/.rels", "word/document.xml"],
        "xlsx": ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml"],
    }[kind]
    with zipfile.ZipFile(path, "r") as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f"ZIP 条目校验失败：{bad}")
        names = set(archive.namelist())
        for name in required:
            if name not in names:
                raise ValueError(f"缺少关键条目：{name}")
        for name in changed:
            ET.fromstring(archive.read(name))


def fingerprint(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_replace(
    source: Path, kind: str, replacements: dict[str, bytes], expected_fingerprint: str | None = None
) -> None:
    if expected_fingerprint and fingerprint(source) != expected_fingerprint:
        raise ValueError("文件已被其他程序修改，请刷新后重新编辑")
    handle, temporary = tempfile.mkstemp(prefix=f".{source.name}.", suffix=".tmp", dir=source.parent)
    os.close(handle)
    temporary_path = Path(temporary)
    try:
        clone_zip(source, temporary_path, replacements)
        validate(temporary_path, kind, list(replacements))
        if expected_fingerprint and fingerprint(source) != expected_fingerprint:
            raise ValueError("写入期间文件被其他程序修改，已取消替换")
        backup = source.with_name(source.name + ".office-backup")
        if not backup.exists():
            shutil.copy2(source, backup)
        os.replace(temporary_path, source)
    finally:
        temporary_path.unlink(missing_ok=True)


def docx_nodes(paragraph: str) -> list[dict[str, object]]:
    nodes = []
    for match in TEXT.finditer(paragraph):
        nodes.append({
            "start": match.start(2),
            "end": match.end(2),
            "raw": match.group(2),
            "text": xml_text(match.group(2)),
        })
    return nodes


def inspect_docx(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as archive:
        document = archive.read("word/document.xml").decode("utf-8")
    paragraphs = []
    warnings = []
    for index, match in enumerate(PARAGRAPH.finditer(document)):
        raw = match.group(0)
        nodes = docx_nodes(raw)
        if not nodes:
            continue
        unsafe = any(token in raw for token in (
            "<w:txbxContent", "<w:fldChar", "<w:instrText", "<w:del", "<w:moveFrom", "<w:br", "<w:tab"
        ))
        if unsafe:
            warnings.append(f"段落 {index + 1} 含文本框、域或修订结构，已设为只读")
        paragraphs.append({
            "id": f"p{index}",
            "paragraph_index": index,
            "text": "".join(str(node["text"]) for node in nodes),
            "editable": not unsafe,
            "node_count": len(nodes),
        })
    return {"kind": "docx", "paragraphs": paragraphs, "warnings": warnings, "fingerprint": fingerprint(path)}


def distribute_edit(old_nodes: list[str], new_text: str) -> list[str]:
    old_text = "".join(old_nodes)
    if old_text == new_text:
        return old_nodes
    offsets = []
    position = 0
    for value in old_nodes:
        offsets.append((position, position + len(value)))
        position += len(value)
    result = list(old_nodes)
    matcher = difflib.SequenceMatcher(a=old_text, b=new_text, autojunk=False)
    for tag, i1, i2, j1, j2 in reversed(matcher.get_opcodes()):
        if tag == "equal":
            continue
        touched = [i for i, (start, end) in enumerate(offsets) if start < i2 and end > i1]
        if not touched:
            target = next((i for i, (_, end) in enumerate(offsets) if end >= i1), len(old_nodes) - 1)
            local = max(0, i1 - offsets[target][0])
            result[target] = result[target][:local] + new_text[j1:j2] + result[target][local:]
            continue
        first, last = touched[0], touched[-1]
        first_start = offsets[first][0]
        prefix = old_nodes[first][: max(0, i1 - first_start)]
        suffix = old_nodes[last][max(0, i2 - offsets[last][0]) :]
        result[first] = prefix + new_text[j1:j2] + (suffix if first == last else "")
        for index in range(first + 1, last):
            result[index] = ""
        if last != first:
            result[last] = suffix
    return result


def save_docx(path: Path, payload: dict[str, object]) -> dict[str, object]:
    changes = payload["changes"]
    expected = payload.get("fingerprint")
    with zipfile.ZipFile(path) as archive:
        original_bytes = archive.read("word/document.xml")
    document = original_bytes.decode("utf-8")
    matches = list(PARAGRAPH.finditer(document))
    patches: list[tuple[int, int, str]] = []
    changed_count = 0
    for identifier, new_text in changes.items():
        index = int(identifier.removeprefix("p"))
        if index >= len(matches):
            raise ValueError(f"段落映射已失效：{identifier}")
        paragraph_match = matches[index]
        paragraph = paragraph_match.group(0)
        if any(token in paragraph for token in (
            "<w:txbxContent", "<w:fldChar", "<w:instrText", "<w:del", "<w:moveFrom", "<w:br", "<w:tab"
        )):
            raise ValueError(f"拒绝修改含复杂结构的段落：{identifier}")
        nodes = docx_nodes(paragraph)
        old_nodes = [str(node["text"]) for node in nodes]
        replacements = distribute_edit(old_nodes, new_text)
        if replacements == old_nodes:
            continue
        changed_count += 1
        for node, value in zip(nodes, replacements):
            if value != node["text"]:
                patches.append((
                    paragraph_match.start() + int(node["start"]),
                    paragraph_match.start() + int(node["end"]),
                    escape_text(value),
                ))
    for start, end, value in sorted(patches, reverse=True):
        document = document[:start] + value + document[end:]
    if changed_count:
        safe_replace(path, "docx", {"word/document.xml": document.encode("utf-8")}, expected)
    return {"saved": changed_count, "backup": str(path) + ".office-backup", "fingerprint": fingerprint(path)}


def relationship_targets(archive: zipfile.ZipFile) -> dict[str, str]:
    root = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    return {node.attrib["Id"]: node.attrib["Target"] for node in root.findall(f"{{{PKG_R}}}Relationship")}


def normalize_sheet_target(target: str) -> str:
    target = target.replace("\\", "/")
    if target.startswith("/"):
        return target.lstrip("/")
    while target.startswith("../"):
        target = target[3:]
    return "xl/" + target.removeprefix("xl/")


def shared_strings(archive: zipfile.ZipFile) -> list[dict[str, object]]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return [
        {
            "text": "".join(node.text or "" for node in item.iter(f"{{{S}}}t")),
            "rich": item.find("s:r", NS) is not None,
        }
        for item in root.findall("s:si", NS)
    ]


def workbook_info(archive: zipfile.ZipFile) -> list[dict[str, str]]:
    root = ET.fromstring(archive.read("xl/workbook.xml"))
    targets = relationship_targets(archive)
    result = []
    for sheet in root.findall("s:sheets/s:sheet", NS):
        relation = sheet.attrib[f"{{{R}}}id"]
        result.append({"name": sheet.attrib["name"], "path": normalize_sheet_target(targets[relation])})
    return result


def column_number(reference: str) -> int:
    value = 0
    for char in re.match(r"[A-Z]+", reference.upper()).group(0):
        value = value * 26 + ord(char) - 64
    return value


def column_name(number: int) -> str:
    result = ""
    while number:
        number, remainder = divmod(number - 1, 26)
        result = chr(65 + remainder) + result
    return result


def date_style_indexes(archive: zipfile.ZipFile) -> set[int]:
    if "xl/styles.xml" not in archive.namelist():
        return set()
    root = ET.fromstring(archive.read("xl/styles.xml"))
    custom = {
        int(node.attrib["numFmtId"]): node.attrib.get("formatCode", "")
        for node in root.findall("s:numFmts/s:numFmt", NS)
    }
    built_in = set(range(14, 23)) | set(range(45, 48))
    indexes = set()
    cell_xfs = root.find("s:cellXfs", NS)
    if cell_xfs is None:
        return indexes
    for index, xf in enumerate(cell_xfs.findall("s:xf", NS)):
        number_format = int(xf.attrib.get("numFmtId", "0"))
        code = custom.get(number_format, "").lower()
        cleaned = re.sub(r'"[^"]*"|\\.|\[[^]]*\]', "", code)
        if number_format in built_in or ("y" in cleaned and ("d" in cleaned or "m" in cleaned)):
            indexes.add(index)
    return indexes


def excel_date(value: str, date_1904: bool) -> str:
    epoch = dt.datetime(1904, 1, 1) if date_1904 else dt.datetime(1899, 12, 30)
    result = epoch + dt.timedelta(days=float(value))
    return result.date().isoformat() if result.time() == dt.time() else result.isoformat(sep=" ", timespec="seconds")


def cell_value(
    cell: ET.Element, strings: list[dict[str, object]], dates: set[int], date_1904: bool
) -> tuple[str, str]:
    formula = cell.find("s:f", NS)
    if formula is not None:
        formula_kind = formula.attrib.get("t")
        kind = "formula-complex" if formula_kind in {"array", "dataTable", "shared"} else "formula"
        return "=" + (formula.text or ""), kind
    kind = cell.attrib.get("t", "n")
    value = cell.find("s:v", NS)
    raw = value.text if value is not None and value.text is not None else ""
    if kind == "s":
        item = strings[int(raw)] if raw else {"text": "", "rich": False}
        return str(item["text"]), ("rich-string" if item["rich"] else "string")
    if kind == "inlineStr":
        value = "".join(node.text or "" for node in cell.findall(".//s:t", NS))
        return value, ("rich-string" if cell.find("s:is/s:r", NS) is not None else "string")
    if kind == "b":
        return ("TRUE" if raw == "1" else "FALSE"), "boolean"
    if kind == "str":
        return raw, "string"
    if raw and int(cell.attrib.get("s", "0")) in dates:
        try:
            return excel_date(raw, date_1904), "date"
        except ValueError:
            pass
    return raw, "number"


def inspect_xlsx(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as archive:
        strings = shared_strings(archive)
        sheets = workbook_info(archive)
        dates = date_style_indexes(archive)
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        properties = workbook.find("s:workbookPr", NS)
        date_1904 = properties is not None and properties.attrib.get("date1904") in {"1", "true"}
        for sheet in sheets:
            root = ET.fromstring(archive.read(sheet["path"]))
            cells = {}
            max_row = max_col = 0
            for cell in root.findall(".//s:sheetData/s:row/s:c", NS):
                reference = cell.attrib["r"]
                value, kind = cell_value(cell, strings, dates, date_1904)
                cells[reference] = {"value": value, "kind": kind, "style": cell.attrib.get("s")}
                match = re.match(r"([A-Z]+)(\d+)", reference)
                max_col = max(max_col, column_number(match.group(1)))
                max_row = max(max_row, int(match.group(2)))
            merges = [node.attrib["ref"] for node in root.findall("s:mergeCells/s:mergeCell", NS)]
            sheet["cells"] = cells
            sheet["max_row"] = min(max_row, 1000)
            sheet["max_col"] = min(max_col, 52)
            sheet["merges"] = merges
    return {"kind": "xlsx", "sheets": sheets, "warnings": [], "fingerprint": fingerprint(path)}


def replace_cell(
    sheet_xml: str, reference: str, old_kind: str, old_value: str, new_value: str, date_1904: bool = False
) -> str:
    pattern = re.compile(CELL_PATTERN % (re.escape(reference), re.escape(reference)), re.S)
    match = pattern.search(sheet_xml)

    def new_cell(attributes: str) -> str:
        if old_kind == "new-formula":
            return f"<c{attributes}><f>{escape_text(new_value[1:])}</f></c>"
        if old_kind == "new-number":
            return f"<c{attributes}><v>{new_value}</v></c>"
        if old_kind == "new-boolean":
            encoded = "1" if new_value.upper() == "TRUE" else "0"
            return f'<c{attributes} t="b"><v>{encoded}</v></c>'
        return f'<c{attributes} t="inlineStr"><is><t>{escape_text(new_value)}</t></is></c>'

    if not match:
        self_closing = re.search(
            rf"<c\b([^>]*\br=(?:\"{re.escape(reference)}\"|'{re.escape(reference)}')[^>]*)/>",
            sheet_xml,
        )
        if self_closing:
            attributes = self_closing.group(1)
            attributes = re.sub(r"\s+t=(?:\"[^\"]*\"|'[^']*')", "", attributes)
            replacement = new_cell(attributes)
            return sheet_xml[:self_closing.start()] + replacement + sheet_xml[self_closing.end():]
        row_number = int(re.search(r"\d+", reference).group(0))
        inserted_cell = new_cell(f' r="{reference}"')
        row_pattern = re.compile(rf"(<row\b[^>]*\br=(?:\"{row_number}\"|'{row_number}')[^>]*>)(.*?)(</row>)", re.S)
        row_match = row_pattern.search(sheet_xml)
        if row_match:
            cell_pattern = r"<c\b[^>]*\br=(?:\"([A-Z]+\d+)\"|'([A-Z]+\d+)')[^>]*>.*?</c>"
            cells = list(re.finditer(cell_pattern, row_match.group(2), re.S))
            body = row_match.group(2)
            target_col = column_number(re.match(r"[A-Z]+", reference).group(0))
            offset = len(body)
            for cell_match in cells:
                cell_ref = cell_match.group(1) or cell_match.group(2)
                if column_number(re.match(r"[A-Z]+", cell_ref).group(0)) > target_col:
                    offset = cell_match.start()
                    break
            body = body[:offset] + inserted_cell + body[offset:]
            return sheet_xml[:row_match.start(2)] + body + sheet_xml[row_match.end(2):]
        sheet_data = re.search(r"(<sheetData(?:\s[^>]*)?>)(.*?)(</sheetData>)", sheet_xml, re.S)
        if not sheet_data:
            raise ValueError("工作表缺少 sheetData")
        new_row = f'<row r="{row_number}">{inserted_cell}</row>'
        body = sheet_data.group(2)
        rows = list(re.finditer(r"<row\b[^>]*\br=(?:\"(\d+)\"|'(\d+)')[^>]*>.*?</row>", body, re.S))
        offset = len(body)
        for row in rows:
            if int(row.group(1) or row.group(2)) > row_number:
                offset = row.start()
                break
        body = body[:offset] + new_row + body[offset:]
        return sheet_xml[:sheet_data.start(2)] + body + sheet_xml[sheet_data.end(2):]
    opening, body, closing = match.groups()
    if old_kind in {"formula-complex", "rich-string"}:
        raise ValueError(f"{reference} 含共享/数组公式或富文本，已拒绝轻度编辑")
    if old_kind == "formula":
        if not new_value.startswith("="):
            raise ValueError(f"{reference} 是公式单元格；修改公式必须保留开头的 =")
        formula = re.search(r"(<f(?:\s[^>]*)?>)(.*?)(</f>)", body, re.S)
        if not formula:
            raise ValueError(f"找不到 {reference} 的公式节点")
        body = body[: formula.start(2)] + escape_text(new_value[1:]) + body[formula.end(2) :]
        body = re.sub(r"<v(?:\s[^>]*)?>.*?</v>", "", body, count=1, flags=re.S)
    elif old_kind == "boolean":
        normalized = new_value.strip().upper()
        if normalized not in {"TRUE", "FALSE"}:
            raise ValueError(f"{reference} 的布尔值只能是 TRUE 或 FALSE")
        encoded = "1" if normalized == "TRUE" else "0"
        body = re.sub(
            r"(<v(?:\s[^>]*)?>).*?(</v>)", rf"\g<1>{encoded}\g<2>", body, count=1, flags=re.S
        )
    elif old_kind == "number":
        try:
            float(new_value)
        except ValueError as error:
            raise ValueError(f"{reference} 必须保持为数字") from error
        body = re.sub(r"(<v(?:\s[^>]*)?>).*?(</v>)", rf"\g<1>{new_value}\g<2>", body, count=1, flags=re.S)
    elif old_kind == "date":
        try:
            parsed = dt.datetime.fromisoformat(new_value)
        except ValueError:
            try:
                parsed = dt.datetime.combine(dt.date.fromisoformat(new_value), dt.time())
            except ValueError as error:
                raise ValueError(f"{reference} 必须保持为 ISO 日期或日期时间") from error
        epoch = dt.datetime(1904, 1, 1) if date_1904 else dt.datetime(1899, 12, 30)
        serial = (parsed - epoch).total_seconds() / 86400
        body = re.sub(r"(<v(?:\s[^>]*)?>).*?(</v>)", rf"\g<1>{serial:g}\g<2>", body, count=1, flags=re.S)
    else:
        opening = re.sub(r"\s+t=(?:\"[^\"]*\"|'[^']*')", "", opening)
        opening = opening[:-1] + ' t="inlineStr">'
        body = f"<is><t>{escape_text(new_value)}</t></is>"
    return sheet_xml[: match.start()] + opening + body + closing + sheet_xml[match.end() :]


def save_xlsx(path: Path, payload: dict[str, object]) -> dict[str, object]:
    changes_by_sheet = payload["changes"]
    expected = payload.get("fingerprint")
    with zipfile.ZipFile(path) as archive:
        sheets = workbook_info(archive)
        originals = {sheet["path"]: archive.read(sheet["path"]).decode("utf-8") for sheet in sheets}
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        properties = workbook.find("s:workbookPr", NS)
        date_1904 = properties is not None and properties.attrib.get("date1904") in {"1", "true"}
    replacements = {}
    count = 0
    for raw_index, changes in changes_by_sheet.items():
        sheet_path = sheets[int(raw_index)]["path"]
        sheet_xml = originals[sheet_path]
        for reference, change in changes.items():
            if change["old"] == change["new"]:
                continue
            sheet_xml = replace_cell(
                sheet_xml, reference, change["kind"], change["old"], change["new"], date_1904
            )
            count += 1
        if sheet_xml != originals[sheet_path]:
            replacements[sheet_path] = sheet_xml.encode("utf-8")
    if count:
        safe_replace(path, "xlsx", replacements, expected)
    return {"saved": count, "backup": str(path) + ".office-backup", "fingerprint": fingerprint(path)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("inspect-docx", "save-docx", "inspect-xlsx", "save-xlsx", "validate"))
    parser.add_argument("path")
    parser.add_argument("--input")
    args = parser.parse_args()
    path = Path(args.path).resolve()
    if args.command == "inspect-docx":
        write_json(inspect_docx(path))
    elif args.command == "save-docx":
        write_json(save_docx(path, read_json(args.input)))
    elif args.command == "inspect-xlsx":
        write_json(inspect_xlsx(path))
    elif args.command == "save-xlsx":
        write_json(save_xlsx(path, read_json(args.input)))
    else:
        kind = path.suffix.lower().lstrip(".")
        validate(path, kind, [])
        write_json({"valid": True})


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Office OOXML：{error}", file=sys.stderr)
        raise SystemExit(1) from None
