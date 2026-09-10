"""Regression tests for minimal, safe Office OOXML edits."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("office_ooxml", ROOT / "scripts" / "office_ooxml.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


CONTENT_TYPES = b'<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>'
ROOT_RELS = (
    b'<?xml version="1.0"?><Relationships '
    b'xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'
)


def make_zip(path: Path, entries: dict[str, bytes]) -> None:
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, value in entries.items():
            archive.writestr(name, value)


def test_docx(root: Path) -> None:
    document = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
        '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>项目</w:t></w:r>'
        '<w:r><w:rPr><w:i/></w:rPr><w:t>名称</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>相同文本</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>相同文本</w:t></w:r></w:p>'
        '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>中文表格</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
        '<w:p><w:r><w:fldChar w:fldCharType="begin"/><w:t>复杂域</w:t></w:r></w:p>'
        '</w:body></w:document>'
    ).encode()
    extra = b"unchanged image bytes"
    header = b"unchanged header xml"
    path = root / "sample.docx"
    make_zip(path, {
        "[Content_Types].xml": CONTENT_TYPES,
        "_rels/.rels": ROOT_RELS,
        "word/document.xml": document,
        "word/media/image1.png": extra,
        "word/header1.xml": header,
    })
    original_package = path.read_bytes()
    inspected = MODULE.inspect_docx(path)
    assert inspected["paragraphs"][0]["text"] == "项目名称"
    assert inspected["paragraphs"][0]["role"] == "heading"
    assert inspected["paragraphs"][0]["level"] == 2
    assert inspected["paragraphs"][1]["id"] != inspected["paragraphs"][2]["id"]
    assert inspected["paragraphs"][3]["role"] == "table"
    assert inspected["paragraphs"][-1]["editable"] is False
    MODULE.save_docx(path, {"fingerprint": MODULE.fingerprint(path), "changes": {
        "p0": "工程名称", "p2": "第二处文本"
    }})
    with zipfile.ZipFile(path) as archive:
        updated = archive.read("word/document.xml").decode()
        assert archive.read("word/media/image1.png") == extra
        assert archive.read("word/header1.xml") == header
    expected = document.decode().replace("项目", "工程", 1).replace("<w:t>相同文本</w:t>", "<w:t>相同文本</w:t>", 1)
    second = expected.find("<w:t>相同文本</w:t>", expected.find("<w:t>相同文本</w:t>") + 1)
    expected = expected[:second] + expected[second:].replace("<w:t>相同文本</w:t>", "<w:t>第二处文本</w:t>", 1)
    assert updated == expected
    assert path.with_name(path.name + ".office-backup").read_bytes() == original_package

    stale = MODULE.inspect_docx(path)["fingerprint"]
    with zipfile.ZipFile(path, "a") as archive:
        archive.comment = b"external change"
    externally_changed = path.read_bytes()
    try:
        MODULE.save_docx(path, {"fingerprint": stale, "changes": {"p0": "禁止覆盖"}})
    except ValueError as error:
        assert "其他程序修改" in str(error)
    else:
        raise AssertionError("stale DOCX edit was not rejected")
    assert path.read_bytes() == externally_changed


def test_xlsx(root: Path) -> None:
    workbook = (
        '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '<sheet name="施工情况" sheetId="1" r:id="rId1"/><sheet name="统计" sheetId="2" r:id="rId2"/>'
        '</sheets></workbook>'
    ).encode()
    rels = (
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Target="worksheets/sheet1.xml" Type="worksheet"/>'
        '<Relationship Id="rId2" Target="worksheets/sheet2.xml" Type="worksheet"/>'
        '</Relationships>'
    ).encode()
    shared = (
        '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<si><t>施工中</t></si><si><t>保持共享</t></si>'
        '<si><r><rPr><b/></rPr><t>富</t></r><r><t>文本</t></r></si></sst>'
    ).encode()
    sheet1 = (
        '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData><row r="3"><c r="A3" t="s"><v>1</v></c><c r="B3" s="1" t="s"><v>0</v></c>'
        '<c r="C3"><f>1+1</f><v>2</v></c><c r="D3" t="b"><v>1</v></c></row>'
        '<row r="4"><c r="B4" s="2"><v>45292</v></c><c r="F4" t="s"><v>2</v></c></row></sheetData>'
        '<mergeCells count="1"><mergeCell ref="A1:B1"/></mergeCells></worksheet>'
    ).encode()
    sheet2 = (
        b'<?xml version="1.0"?><worksheet '
        b'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>'
    )
    drawing = b"drawing must survive"
    styles = (
        '<?xml version="1.0"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<cellXfs count="3"><xf numFmtId="0"/><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs>'
        '</styleSheet>'
    ).encode()
    path = root / "sample.xlsx"
    make_zip(path, {
        "[Content_Types].xml": CONTENT_TYPES,
        "_rels/.rels": ROOT_RELS,
        "xl/workbook.xml": workbook,
        "xl/_rels/workbook.xml.rels": rels,
        "xl/sharedStrings.xml": shared,
        "xl/styles.xml": styles,
        "xl/worksheets/sheet1.xml": sheet1,
        "xl/worksheets/sheet2.xml": sheet2,
        "xl/drawings/drawing1.xml": drawing,
    })
    inspected = MODULE.inspect_xlsx(path)
    assert inspected["sheets"][0]["cells"]["B3"]["value"] == "施工中"
    assert inspected["sheets"][0]["cells"]["C3"]["value"] == "=1+1"
    assert inspected["sheets"][0]["cells"]["B4"] == {
        "value": "2024-01-01", "kind": "date", "style": "2"
    }
    assert inspected["sheets"][0]["cells"]["F4"]["kind"] == "rich-string"
    try:
        MODULE.replace_cell(sheet1.decode(), "F4", "rich-string", "富文本", "普通文本")
    except ValueError as error:
        assert "富文本" in str(error)
    else:
        raise AssertionError("rich text edit was not rejected")
    MODULE.save_xlsx(path, {"fingerprint": MODULE.fingerprint(path), "changes": {"0": {
        "B3": {"old": "施工中", "new": "已完成", "kind": "string"},
        "C3": {"old": "=1+1", "new": "=2+2", "kind": "formula"},
        "E3": {"old": "", "new": "新增", "kind": "string"},
        "B4": {"old": "2024-01-01", "new": "2024-01-02", "kind": "date"},
    }}})
    with zipfile.ZipFile(path) as archive:
        updated = archive.read("xl/worksheets/sheet1.xml").decode()
        assert archive.read("xl/worksheets/sheet2.xml") == sheet2
        assert archive.read("xl/sharedStrings.xml") == shared
        assert archive.read("xl/drawings/drawing1.xml") == drawing
    assert '<c r="B3" s="1" t="inlineStr"><is><t>已完成</t></is></c>' in updated
    assert '<c r="C3"><f>2+2</f></c>' in updated
    assert '<c r="E3" t="inlineStr"><is><t>新增</t></is></c>' in updated
    assert '<c r="B4" s="2"><v>45293</v></c>' in updated
    assert '<mergeCell ref="A1:B1"/>' in updated


with tempfile.TemporaryDirectory(prefix="office-ooxml-") as temporary:
    test_root = Path(temporary)
    test_docx(test_root)
    test_xlsx(test_root)

print("PASS: DOCX/XLSX minimal OOXML edits and safe replacement")
