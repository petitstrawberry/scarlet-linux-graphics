#!/usr/bin/env python3
"""Fetch exact Git inputs and export the corresponding source trees."""
import json
import pathlib
import re
import subprocess
import sys

producer = pathlib.Path(__file__).resolve().parent
lock = json.loads((producer / "sources.lock.json").read_text())
if lock["schema"] != 1 or lock["target"] != "aarch64-unknown-linux-gnu":
    raise SystemExit("Unsupported graphics source lock")
work = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2]).resolve()
for name, source in lock["sources"].items():
    if not re.fullmatch(r"[a-z]+", name) or not re.fullmatch(r"[0-9a-f]{40}", source["revision"]):
        raise SystemExit("Invalid pinned source")
    directory = work / name
    if not (directory / ".git").exists():
        directory.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "--quiet", str(directory)], check=True)
        subprocess.run(["git", "-C", str(directory), "remote", "add", "origin", source["url"]], check=True)
        subprocess.run(["git", "-C", str(directory), "fetch", "--depth", "1", "origin", source["revision"]], check=True)
        subprocess.run(["git", "-C", str(directory), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True)
    actual = subprocess.check_output(["git", "-C", str(directory), "rev-parse", "HEAD"], text=True).strip()
    if actual != source["revision"]:
        raise SystemExit(f"Cached source revision mismatch: {name}")
    if subprocess.check_output(["git", "-C", str(directory), "status", "--porcelain"]):
        raise SystemExit(f"Cached source is dirty: {name}")
    destination = output / "upstream" / name
    destination.mkdir(parents=True, exist_ok=True)
    archive = subprocess.Popen(["git", "-C", str(directory), "archive", "HEAD"], stdout=subprocess.PIPE)
    subprocess.run(["tar", "-xf", "-", "-C", str(destination)], stdin=archive.stdout, check=True)
    archive.stdout.close()
    if archive.wait() != 0:
        raise SystemExit(f"Source export failed: {name}")
