#!/usr/bin/env python3
"""Tiny synthetic client for stream lifecycle tests; never connects to a database."""
import os
import json
import signal
import sys
import time

args = sys.argv[1:]
quick = "--quick" in args
args = [arg for arg in args if arg not in ("--quick", "--batch")]
mode = args[0] if args else "ok"

if mode == "ok":
    incoming = sys.stdin.buffer.read()
    expected = b"SELECT 'literal\\ntext';\n"
    output = (
        "quick\tstdin_ok\tenv_ok\n"
        f"{int(quick)}\t{int(incoming == expected)}\t"
        f"{int(os.environ.get('SQL_STREAM_TEST_VALUE') == 'fixture-value')}\n"
    ).encode()
    for start in range(0, len(output), 3):
        os.write(1, output[start:start + 3])
elif mode == "unicode":
    output = "甲\t乙\r\n中\\t文\tline\\nnext\r\n尾\t\\N".encode()
    for byte in output:
        os.write(1, bytes([byte]))
        time.sleep(0.001)
elif mode == "rows":
    os.write(1, b"a\tb\n")
    while True:
        os.write(1, b"x\ty\n" * 32)
        time.sleep(0.003)
elif mode == "bytes":
    while True:
        os.write(1, b"x" * 8192)
        time.sleep(0.003)
elif mode == "stderr":
    for _ in range(32):
        os.write(2, b"e" * 8192)
    os.write(1, b"header\nok\n")
elif mode == "fail":
    os.write(1, b"header\npartial\n")
    os.write(2, b"fixture failure")
    sys.exit(7)
elif mode == "hang":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    os.write(1, b"ready\n")
    while True:
        time.sleep(0.05)
elif mode == "producer":
    with open(args[1], "w", encoding="utf-8") as output:
        json.dump({"pid": os.getpid(), "ppid": os.getppid(), "pgid": os.getpgrp()}, output)
    while True:
        os.write(1, b"child-output\n")
        time.sleep(0.01)
elif mode == "marker":
    with open(args[1], "w", encoding="utf-8") as output:
        output.write("spawned")
else:
    raise SystemExit(f"Unknown fixture mode: {mode}")
