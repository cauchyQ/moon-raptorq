"""Local release checks, including actual CLI and examples on three backends."""
from pathlib import Path
import json
import platform
import subprocess

ROOT = Path(__file__).resolve().parents[1]
completed = []

def run(*command):
    result = subprocess.run(command, cwd=ROOT, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        print(result.stdout)
        print(result.stderr)
        raise SystemExit(f"Failed: {' '.join(command)} (exit {result.returncode})")
    completed.append(list(command))
    print("PASS", " ".join(command), flush=True)
    return result.stdout

run("moon", "info")
run("moon", "fmt")
for target in ["wasm", "wasm-gc", "js"]:
    run("moon", "check", "--deny-warn", "--target", target)
    run("moon", "build", "--release", "--deny-warn", "--target", target)
    output = run("moon", "test", "--release", "--deny-warn", "--target", target)
    print(output.strip(), flush=True)
    for example in ["multicast", "device", "edge", "object", "resume"]:
        output = run("moon", "run", f"examples/{example}", "--release", "--target", target)
        assert "PASS" in output

def cli(*arguments):
    return subprocess.run(["moon", "run", "cmd/main", "--release", "--", *arguments], cwd=ROOT, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE)

original = bytes(range(1, 13)).hex()
result = cli("encode", "4", original, "3", "15")
assert result.returncode == 0, result.stderr
lines = [line.split() for line in result.stdout.splitlines()]
oti = next(value for key, value in lines if key == "oti")
packets = [value for key, value in lines if key == "packet"]
assert len(packets) == 15
saved = cli("save", oti, packets[0])
assert saved.returncode == 0
checkpoint = saved.stdout.strip().split()[1]
resumed = cli("resume", checkpoint, *packets[1:])
assert resumed.returncode == 0 and "data " + original in resumed.stdout
waiting = cli("resume", checkpoint)
assert waiting.returncode != 0 and "checkpoint " in waiting.stdout and "waiting:" in waiting.stdout
result = cli("decode", oti, *packets)
assert result.returncode == 0 and "data " + original in result.stdout
result = cli("decode", oti, packets[0])
assert result.returncode != 0 and "waiting:" in result.stdout
for arguments in [
    ("encode", "0", original, "0", "1"),
    ("encode", "4", "x", "0", "1"),
    ("encode", "4", original, "16777215", "2"),
    ("encode", "2147483648", original, "0", "1"),
    ("decode", "00", packets[0]),
]:
    result = cli(*arguments)
    assert result.returncode != 0 and "error:" in result.stdout, result.stdout
assert cli("--help").returncode == 0
assert cli("estimate", "1048576", "4096").returncode == 0
print("PASS CLI repair-only roundtrip, waiting state and invalid arguments", flush=True)

report = dict(
    platform=platform.platform(),
    toolchain=run("moon", "version", "--all").strip(),
    commands=completed,
    targets=["wasm", "wasm-gc", "js"],
    examples_per_target=5,
    cli="PASS: independent process encoding/decoding, waiting and validation",
    result="PASS",
)
(ROOT / "reports/local-checks.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
