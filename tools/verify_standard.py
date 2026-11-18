"""Full-size bidirectional checks against independent Rust; no generated LOC."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def oracle(*paths, script_name="standard_oracle.py"):
    script = ROOT / "tools" / script_name
    if os.name == "nt":
        def linux(path):
            value = str(Path(path).resolve()).replace("\\", "/")
            return "/mnt/" + value[0].lower() + value[2:]
        command = ["wsl", "-e", "python3", linux(script), *map(linux, paths)]
    else:
        command = [sys.executable, str(script), *map(str, paths)]
    output = subprocess.check_output(command, cwd=ROOT).decode("utf-8", errors="replace")
    return json.loads(next(line for line in reversed(output.splitlines()) if line.startswith(("[", "{"))))


def main():
    reference = oracle()
    env = os.environ.copy()
    for case in reference:
        env[f"RAPTORQ_RUST_{case['k']}"] = case["repairs_hex"]
    print("Rust fixtures ready; executing sparse MoonBit encoder and decoder", flush=True)
    output = subprocess.check_output(["moon", "run", "cmd/standard-interop", "--release"], cwd=ROOT, env=env, text=True, encoding="utf-8")
    cases = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
    assert len(cases) == 4
    for actual, expected in zip(cases, reference):
        assert actual["k"] == expected["k"]
        assert actual["repair"] == expected["repair"]
        assert actual["repairs_hex"] == expected["repairs_hex"]
        assert actual["recovered"] is True
    directory = ROOT / ".verification"
    directory.mkdir(exist_ok=True)
    export = directory / "standard-packets.json"
    export.write_text(json.dumps(cases), encoding="utf-8")
    reverse = oracle(export)
    assert reverse["reverse"] == "PASS"
    report = {
        "reference": "Rust raptorq 2.0.0",
        "symbol_size": 1,
        "sparse_coefficient_budget": 33554432,
        "profiles": [c["k"] for c in cases],
        "pattern": "omit source ESI divisible by 10; receive ceil(K/10)+16 repairs",
        "reference_sha256": hashlib.sha256(json.dumps(reference, sort_keys=True).encode()).hexdigest(),
        "moonbit_to_rust": reverse,
        "rust_to_moonbit": "PASS with exact repair-byte comparison",
        "runs": [{k: v for k, v in case.items() if k != "repairs_hex"} for case in cases],
        "scope": "Four parameter points including Kmax; not a statistical certification of section 5.8 across all 477 rows",
    }
    (ROOT / "reports/standard-interop.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
