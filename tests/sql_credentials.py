"""Run: python -B tests/sql_credentials.py. Never prints credential values."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import uuid

spec = importlib.util.spec_from_file_location(
    "sql_credentials", Path(__file__).resolve().parents[1] / "scripts" / "sql_credentials.py")
assert spec and spec.loader
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class CredentialTests(unittest.TestCase):
    def test_name_and_secret_validation(self):
        for name in ["../outside", "user name", "name;command", "-flag", ""]:
            with self.assertRaises(helper.CredentialError):
                helper.validate_name(name)
        self.assertEqual(helper.validate_name("platform_st"), "platform_st")
        for value in ["", "null\0byte"]:
            with self.assertRaises(helper.CredentialError):
                helper.validate_secret(value)

    def test_environment_is_filtered_without_mutation(self):
        values = {"PATH": "safe", "DB_HOST_ST": "example", "DB_PASSWORD_ST": "fake", "MYSQL_PWD": "fake"}
        with patch.dict(os.environ, values, clear=True):
            result = helper.clean_environment()
            self.assertEqual(result, {"PATH": "safe", "DB_HOST_ST": "example"})
            self.assertEqual(os.environ["DB_PASSWORD_ST"], "fake")

    def test_secret_service_preserves_exact_bytes_and_uses_stdin(self):
        secret = "  fictitious @:/% password 中文\r\n "
        with patch.object(helper.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, secret.encode(), b"")) as run:
            backend = helper.SecretServiceStore()
            self.assertEqual(backend.get("platform_st"), secret)
            self.assertEqual(run.call_args.args[0], ["secret-tool", "lookup", "application", "nvim-sql", "connection", "platform_st"])
            backend.set("platform_st", secret)
            self.assertEqual(run.call_args.kwargs["input"], secret.encode())
            self.assertNotIn(secret, run.call_args.args[0])
            self.assertNotIn("shell", run.call_args.kwargs)

    def test_secret_service_hides_backend_errors(self):
        with patch.object(helper.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"", b"must-not-leak")):
            with self.assertRaises(helper.CredentialError) as error:
                helper.SecretServiceStore().get("platform_st")
            self.assertNotIn("must-not-leak", str(error.exception))
        with patch.object(helper.subprocess, "run", side_effect=subprocess.TimeoutExpired("secret-tool", 60)):
            with self.assertRaises(helper.CredentialError):
                helper.SecretServiceStore().get("platform_st")

    def test_migration_verifies_all_before_removing_environment(self):
        class FakeStore:
            values = {}
            fail = False
            def get(self, name):
                if name not in self.values:
                    raise helper.MissingCredential("missing")
                return "mismatch" if self.fail and name == "platform_st_test" else self.values[name]
            def set(self, name, value):
                self.values[name] = value
        backend = FakeStore()
        legacy = {"ST": "fake-a", "STTEST": "fake-b"}
        with patch.object(helper, "WindowsStore", FakeStore), patch.object(helper, "store", return_value=backend), \
                patch.object(helper, "legacy_password", side_effect=legacy.get), \
                patch.object(helper, "remove_legacy") as remove, contextlib.redirect_stdout(io.StringIO()):
            backend.fail = True
            with self.assertRaises(helper.CredentialError):
                helper.migrate(["platform_st", "platform_st_test"], True)
            remove.assert_not_called()
            backend.fail = False
            backend.values = {}
            helper.migrate(["platform_st", "platform_st_test"], True)
            self.assertEqual(remove.call_count, 2)
            backend.values["platform_st"] = "different-existing-value"
            with self.assertRaises(helper.CredentialError):
                helper.migrate(["platform_st"], False)
            self.assertEqual(backend.values["platform_st"], "different-existing-value")

    @unittest.skipUnless(os.name == "nt", "requires real Windows Credential Manager")
    def test_windows_roundtrip_and_cleanup(self):
        backend = helper.WindowsStore()
        name = "nvim_test_" + uuid.uuid4().hex
        secret = " synthetic 中文 / @ : % ${VALUE}\r\n "
        try:
            backend.set(name, secret)
            self.assertEqual(backend.get(name), secret)
            backend.set(name, secret + "changed")
            self.assertEqual(backend.get(name), secret + "changed")
        finally:
            backend.delete(name)
        with self.assertRaises(helper.MissingCredential):
            backend.get(name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
