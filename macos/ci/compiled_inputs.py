"""Reuse tested Swift binaries from successful, same-commit push runs only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time

SCHEMA = 1
ROOT = Path(__file__).resolve().parents[1]


def gh(endpoint):
    return json.loads(subprocess.check_output(["gh", "api", endpoint], text=True))


def toolchain():
    commands = (["xcodebuild", "-version"], ["swift", "--version"])
    return hashlib.sha256("\n".join(subprocess.check_output(c, text=True).strip() for c in commands).encode()).hexdigest()


def trusted_runs(runs, current, repository):
    return [r for r in runs if r["id"] != current["id"]
            and r["run_number"] < current["run_number"]
            and r["head_sha"] == current["head_sha"]
            and r["workflow_id"] == current["workflow_id"]
            and r["event"] == "push"
            and r["head_repository"]["full_name"] == repository]


def find_build(wait_seconds):
    repository = os.environ["GITHUB_REPOSITORY"]
    current = gh(f"repos/{repository}/actions/runs/{os.environ['GITHUB_RUN_ID']}")
    name = f"macos-compiled-v{SCHEMA}-{current['head_sha']}"
    deadline = time.monotonic() + wait_seconds
    while True:
        listing = gh(f"repos/{repository}/actions/workflows/{current['workflow_id']}/runs?head_sha={current['head_sha']}&event=push&per_page=100")
        candidates = trusted_runs(listing["workflow_runs"], current, repository)
        for run in candidates:
            if run["conclusion"] != "success":
                continue
            artifacts = gh(f"repos/{repository}/actions/runs/{run['id']}/artifacts?per_page=100")
            if any(a["name"] == name and not a["expired"] for a in artifacts["artifacts"]):
                print(f"Reusing tested Swift binaries from run {run['id']}")
                with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                    output.write(f"run_id={run['id']}\nartifact={name}\n")
                return
        pending = [r for r in candidates if r["status"] != "completed"]
        if not pending or time.monotonic() >= deadline:
            print("No reusable successful build; performing full tests and compilation.")
            return
        print("Waiting for the earlier same-commit build instead of compiling twice.", flush=True)
        time.sleep(min(20, max(0, deadline - time.monotonic())))


def pack(destination):
    with tempfile.TemporaryDirectory() as temporary:
        stage = Path(temporary)
        for arch in ("arm64", "x86_64"):
            target = stage / f".build-{arch}/release/PixelPin"
            target.parent.mkdir(parents=True)
            shutil.copy2(ROOT / f".build-{arch}/release/PixelPin", target)
        shutil.copytree(ROOT / ".build-arm64/artifacts", stage / ".build-arm64/artifacts", symlinks=True)
        (stage / "manifest.json").write_text(json.dumps({"schema": SCHEMA, "sha": os.environ["GITHUB_SHA"], "toolchain": toolchain()}))
        with tarfile.open(destination, "w:gz") as archive:
            for child in stage.iterdir():
                archive.add(child, arcname=child.name)
    digest = hashlib.sha256(Path(destination).read_bytes()).hexdigest()
    Path(str(destination) + ".sha256").write_text(digest + "\n")


def validate_manifest(manifest, sha, compiler):
    if manifest != {"schema": SCHEMA, "sha": sha, "toolchain": compiler}:
        raise ValueError("Compiled inputs do not match the source commit or toolchain")


def restore(source):
    path = Path(source)
    if hashlib.sha256(path.read_bytes()).hexdigest() != Path(str(path) + ".sha256").read_text().strip():
        raise ValueError("Compiled input checksum mismatch")
    with tempfile.TemporaryDirectory() as temporary:
        stage = Path(temporary)
        with tarfile.open(path) as archive:
            for member in archive.getmembers():
                # Extraction can only populate generated build inputs, never source files.
                parts = Path(member.name).parts
                if not parts or parts[0] not in ("manifest.json", ".build-arm64", ".build-x86_64"):
                    raise ValueError("Unexpected compiled input path")
            archive.extractall(stage, filter="data")
        validate_manifest(json.loads((stage / "manifest.json").read_text()), os.environ["GITHUB_SHA"], toolchain())
        for arch in ("arm64", "x86_64"):
            binary = stage / f".build-{arch}/release/PixelPin"
            subprocess.run(["lipo", str(binary), "-verify_arch", arch], check=True)
        # ditto preserves the framework's executable bits and symlinks.
        for arch in ("arm64", "x86_64"):
            subprocess.run(["ditto", str(stage / f".build-{arch}"), str(ROOT / f".build-{arch}")], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("find", "pack", "restore"))
    parser.add_argument("path", nargs="?")
    parser.add_argument("--wait-seconds", type=int, default=0)
    args = parser.parse_args()
    if args.operation == "find":
        try:
            find_build(args.wait_seconds)
        except (subprocess.CalledProcessError, KeyError, ValueError) as error:
            print(f"::warning::Build lookup unavailable; using a fresh build ({type(error).__name__}).")
    elif args.operation == "pack":
        pack(args.path)
    else:
        restore(args.path)
