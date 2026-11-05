"""Remove signing material and temporary trust from a disposable macOS runner."""
import os
from pathlib import Path
import subprocess


def clean(*command):
    try:
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
    except subprocess.TimeoutExpired:
        print("::warning::Signing cleanup timed out; disposable runner teardown removes remaining state.")


temporary = Path(os.environ["RUNNER_TEMP"])
identity = temporary / "pixelpin-release-identity"
certificate = identity / "certificate.pem"
clean("security", "default-keychain", "-d", "user", "-s", str(Path.home() / "Library/Keychains/login.keychain-db"))
clean("security", "delete-keychain", str(temporary / "pixelpin-release.keychain-db"))
if certificate.exists():
    result = subprocess.run(["openssl", "x509", "-in", str(certificate), "-noout", "-fingerprint", "-sha1"],
                            text=True, capture_output=True, timeout=8, check=True)
    fingerprint = result.stdout.strip().split("=")[1].replace(":", "")
    clean("sudo", "-n", "security", "remove-trusted-cert", "-d", str(certificate))
    clean("sudo", "-n", "security", "delete-certificate", "-Z", fingerprint, "/Library/Keychains/System.keychain")
for name in ("identity.p12", "imported.pem", "imported.der", "expected.der", "certificate.pem"):
    (identity / name).unlink(missing_ok=True)
(temporary / "pixelpin-release.keychain-db").unlink(missing_ok=True)
