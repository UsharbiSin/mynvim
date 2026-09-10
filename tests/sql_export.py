"""Regression checks for SQL result CSV/XLSX export."""

from __future__ import annotations

import csv
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "sql_export.py"
PAYLOAD = {
    "columns": ["编号", "名称", "备注"],
    "rows": [["1", "施工中", "逗号,引号\"和\n换行"], ["2", None, "=1+1"]],
}


def run_export(path: Path, kind: str) -> None:
    payload = {**PAYLOAD, "path": str(path), "format": kind}
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps(payload, ensure_ascii=False),
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=True,
    )
    assert json.loads(result.stdout)["rows"] == 2


with tempfile.TemporaryDirectory(prefix="sql-export-") as temporary:
    root = Path(temporary)
    csv_path = root / "查询结果.csv"
    run_export(csv_path, "csv")
    assert csv_path.read_bytes().startswith(b"\xef\xbb\xbf")
    with csv_path.open(encoding="utf-8-sig", newline="") as stream:
        assert list(csv.reader(stream)) == [PAYLOAD["columns"], [str(v) if v is not None else "" for v in PAYLOAD["rows"][0]], [str(v) if v is not None else "" for v in PAYLOAD["rows"][1]]]

    xlsx_path = root / "查询结果.xlsx"
    run_export(xlsx_path, "xlsx")
    with zipfile.ZipFile(xlsx_path) as archive:
        assert archive.testzip() is None
        sheet = archive.read("xl/worksheets/sheet1.xml").decode()
        assert "施工中" in sheet
        assert "=1+1" in sheet
        assert "<f>" not in sheet

print("PASS: SQL result CSV/XLSX export")
