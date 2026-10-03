#!/usr/bin/env python3
"""Record exact source inputs, runtime files, ABI requirements and tool versions."""
import hashlib
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
producer = pathlib.Path(__file__).resolve().parent.parent
manifest = json.loads((producer / "producer/sources.lock.json").read_text())
manifest["producer_revision"] = sys.argv[2]
manifest["build_environment"] = pathlib.Path("/etc/os-release").read_text()
manifest["tools"] = {name: subprocess.check_output(args, text=True).strip() for name, args in {
    "rustc": ["rustc", "-vV"], "cc": ["cc", "--version"], "meson": ["meson", "--version"],
    "cmake": ["cmake", "--version"], "glibc": ["getconf", "GNU_LIBC_VERSION"]}.items()}
manifest["runtime_files"] = {}
manifest["dynamic_libraries"] = {}
for path in sorted((root / "runtime").rglob("*")):
    relative = str(path.relative_to(root / "runtime"))
    if path.is_symlink():
        manifest["runtime_files"][relative] = {"symlink": str(path.readlink())}
    elif path.is_file():
        manifest["runtime_files"][relative] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        with path.open("rb") as stream:
            elf = stream.read(4) == b"\x7fELF"
        if elf:
            manifest["dynamic_libraries"][relative] = {
                "dynamic": subprocess.check_output(["readelf", "-d", str(path)], text=True),
                "versions": subprocess.check_output(["readelf", "--version-info", str(path)], text=True)}
documentation = root / "runtime/usr/share/doc/scarlet-linux-graphics"
documentation.mkdir(parents=True, exist_ok=True)
(documentation / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(root / "sources/manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
