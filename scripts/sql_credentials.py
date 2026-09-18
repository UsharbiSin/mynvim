"""Local SQL credential helper. Secrets never belong in argv or diagnostic output.

Windows: generic Credential Manager entries, UTF-16LE blobs, current user only.
Linux: Secret Service through secret-tool. No third-party Python packages.
"""
from __future__ import annotations

import argparse
import ctypes
import getpass
import os
import re
import subprocess
import sys
from ctypes import wintypes

PROFILES = {
    "tongyan": "TY",
    "tongyan_test": "TYTEST",
    "platform_st": "ST",
    "platform_st_test": "STTEST",
}
PREFIX = "nvim/sql/"


class CredentialError(Exception):
    """A fixed, non-secret-bearing message safe to show to the user."""


class MissingCredential(CredentialError):
    pass


def validate_name(name: str) -> str:
    if not re.fullmatch(r"[a-z][a-z0-9_]{0,79}", name):
        raise CredentialError("Invalid credential name")
    return name


def validate_secret(secret: str) -> str:
    if not secret or "\x00" in secret:
        raise CredentialError("Password must be nonempty and contain no NUL")
    return secret


def clean_environment() -> dict[str, str]:
    return {k: v for k, v in os.environ.items()
            if not k.upper().startswith("DB_PASSWORD_") and k.upper() != "MYSQL_PWD"}


class WindowsStore:
    def __init__(self) -> None:
        if os.name != "nt":
            raise CredentialError("Windows Credential Manager is unavailable")

        class Credential(ctypes.Structure):
            _fields_ = [
                ("Flags", wintypes.DWORD), ("Type", wintypes.DWORD),
                ("TargetName", wintypes.LPWSTR), ("Comment", wintypes.LPWSTR),
                ("LastWritten", wintypes.FILETIME),
                ("CredentialBlobSize", wintypes.DWORD),
                ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
                ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD),
                ("Attributes", ctypes.c_void_p), ("TargetAlias", wintypes.LPWSTR),
                ("UserName", wintypes.LPWSTR),
            ]

        self.Credential = Credential
        self.api = ctypes.WinDLL("Advapi32.dll", use_last_error=True)
        pointer = ctypes.POINTER(Credential)
        self.api.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD,
                                       wintypes.DWORD, ctypes.POINTER(pointer)]
        self.api.CredReadW.restype = wintypes.BOOL
        self.api.CredWriteW.argtypes = [pointer, wintypes.DWORD]
        self.api.CredWriteW.restype = wintypes.BOOL
        self.api.CredDeleteW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD]
        self.api.CredDeleteW.restype = wintypes.BOOL
        self.api.CredFree.argtypes = [ctypes.c_void_p]
        self.api.CredFree.restype = None

    def get(self, name: str) -> str:
        target = PREFIX + validate_name(name)
        result = ctypes.POINTER(self.Credential)()
        if not self.api.CredReadW(target, 1, 0, ctypes.byref(result)):
            code = ctypes.get_last_error()
            if code == 1168:
                raise MissingCredential("Credential not found; run the set or migrate command")
            raise CredentialError(f"CredRead failed (Windows error {code})")
        try:
            raw = ctypes.string_at(result.contents.CredentialBlob,
                                   result.contents.CredentialBlobSize)
            return validate_secret(raw.decode("utf-16-le"))
        finally:
            ctypes.memset(result.contents.CredentialBlob, 0, result.contents.CredentialBlobSize)
            self.api.CredFree(result)

    def set(self, name: str, secret: str) -> None:
        target = PREFIX + validate_name(name)
        raw = validate_secret(secret).encode("utf-16-le")
        if len(raw) > 2560:
            raise CredentialError("Credential exceeds the Windows blob size limit")
        blob = (ctypes.c_ubyte * len(raw)).from_buffer_copy(raw)
        credential = self.Credential()
        credential.Type = 1  # CRED_TYPE_GENERIC
        credential.TargetName = target
        credential.Comment = "Neovim SQL credential"
        credential.CredentialBlobSize = len(raw)
        credential.CredentialBlob = blob
        credential.Persist = 2  # Same user, subsequent logons on this machine; not machine-wide.
        credential.UserName = name
        try:
            if not self.api.CredWriteW(ctypes.byref(credential), 0):
                raise CredentialError(f"CredWrite failed (Windows error {ctypes.get_last_error()})")
        finally:
            ctypes.memset(blob, 0, len(raw))

    def delete(self, name: str) -> None:
        if not self.api.CredDeleteW(PREFIX + validate_name(name), 1, 0):
            code = ctypes.get_last_error()
            if code != 1168:
                raise CredentialError(f"CredDelete failed (Windows error {code})")


class SecretServiceStore:
    @staticmethod
    def command(action: str, name: str, secret: str | None = None) -> bytes:
        args = ["secret-tool", action]
        if action == "store":
            args.append("--label=Neovim SQL / " + validate_name(name))
        args += ["application", "nvim-sql", "connection", validate_name(name)]
        try:
            result = subprocess.run(
                args, input=secret.encode("utf-8") if secret is not None else None,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                env=clean_environment(), timeout=60, check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise CredentialError("secret-tool unavailable or unlock timed out") from exc
        if result.returncode:
            raise CredentialError("Secret Service failed; check the service, unlock state and credential name")
        # secret-tool does NOT append a newline when stdout is a pipe. Do not strip secrets.
        return result.stdout

    def get(self, name: str) -> str:
        return validate_secret(self.command("lookup", name).decode("utf-8"))

    def set(self, name: str, secret: str) -> None:
        self.command("store", name, validate_secret(secret))

    def delete(self, name: str) -> None:
        self.command("clear", name)


def store() -> WindowsStore | SecretServiceStore:
    return WindowsStore() if os.name == "nt" else SecretServiceStore()


def legacy_password(suffix: str) -> str | None:
    key = "DB_PASSWORD_" + suffix
    if os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as handle:
                value, _ = winreg.QueryValueEx(handle, key)
                return str(value) if value else None
        except FileNotFoundError:
            pass
    return os.environ.get(key) or None


def remove_legacy(suffix: str, expected: str) -> None:
    key = "DB_PASSWORD_" + suffix
    if os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0,
                                winreg.KEY_QUERY_VALUE | winreg.KEY_SET_VALUE) as handle:
                value, _ = winreg.QueryValueEx(handle, key)
                if value != expected:
                    raise CredentialError("Environment changed during migration; old value was not removed")
                winreg.DeleteValue(handle, key)
        except FileNotFoundError:
            pass
    os.environ.pop(key, None)


def migrate(names: list[str], remove_env: bool) -> None:
    backend = store()
    verified: list[tuple[str, str]] = []
    for name in names:
        secret = legacy_password(PROFILES[name])
        if secret is None:
            print(f"{name}: no legacy password; skipped")
            continue
        # Idempotent migration must never overwrite a different credential silently.
        if isinstance(backend, WindowsStore):
            try:
                existing = backend.get(name)
            except MissingCredential:
                existing = None
            if existing is not None and existing != secret:
                raise CredentialError("Existing credential differs; use set explicitly before migrating")
        else:
            # Linux: lookup failure may mean a locked/missing service, not a missing item.
            # Let secret-tool store handle unlock; require explicit user confirmation below.
            if not sys.stdin.isatty():
                raise CredentialError("Linux migration requires an interactive terminal")
            if input(f"Store legacy credential for {name}? [y/N] ").lower() != "y":
                continue
        backend.set(name, secret)
        if backend.get(name) != secret:
            raise CredentialError("Credential read-back verification failed; environment retained")
        verified.append((name, secret))
        print(f"{name}: stored and verified")
    # Only remove after EVERY attempted store and read-back has succeeded.
    if remove_env:
        for name, secret in verified:
            remove_legacy(PROFILES[name], secret)
            print(f"{name}: legacy user environment entry removed (where supported)")
        print("Restart existing terminals/editors. Linux shell startup files must be cleaned manually.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["get", "set", "check", "migrate"])
    parser.add_argument("name", nargs="?", default="all")
    parser.add_argument("--remove-env", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "migrate":
            names = list(PROFILES) if args.name == "all" else [args.name]
            if any(name not in PROFILES for name in names):
                raise CredentialError("Unknown migration profile")
            migrate(names, args.remove_env)
        elif args.action == "get":
            if sys.stdout.isatty():
                raise CredentialError("Refusing to print a password to a terminal; use check")
            sys.stdout.buffer.write(store().get(validate_name(args.name)).encode("utf-8"))
        elif args.action == "set":
            if not sys.stdin.isatty():
                raise CredentialError("Use an interactive terminal to enter the password")
            name = validate_name(args.name)
            secret = validate_secret(getpass.getpass("Database password: "))
            if getpass.getpass("Confirm password: ") != secret:
                raise CredentialError("Passwords do not match")
            backend = store()
            backend.set(name, secret)
            if backend.get(name) != secret:
                raise CredentialError("Read-back verification failed")
            print(f"{name}: stored and verified")
        else:
            names = list(PROFILES) if args.name == "all" else [validate_name(args.name)]
            backend = store()
            failed = False
            for name in names:
                try:
                    backend.get(name)
                    print(f"{name}: available")
                except CredentialError:
                    failed = True
                    print(f"{name}: unavailable")
            return int(failed)
        return 0
    except (CredentialError, UnicodeError, OSError) as exc:
        # Do not include arbitrary exceptions, subprocess stderr, argv or secret values.
        message = str(exc) if isinstance(exc, CredentialError) else "Credential operation failed"
        print(message, file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Credential operation cancelled", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
