"""Reproduce the bounded RFC constants from the attributed Rust revision."""
from pathlib import Path
import argparse
import re
import subprocess
import urllib.request

REVISION = "73e4e97b0e4d9048c49d195903e440662ef1660b"
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--reference", type=Path, help="optional local cberner/raptorq checkout")
arguments = parser.parse_args()

def read(name):
    if arguments.reference:
        actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=arguments.reference, text=True).strip()
        assert actual == REVISION, actual
        return (arguments.reference / "src" / name).read_text(encoding="utf-8")
    url = f"https://raw.githubusercontent.com/cberner/raptorq/{REVISION}/src/{name}"
    with urllib.request.urlopen(url) as response:
        return response.read().decode()

rng = read("rng.rs")
parameters = read("systematic_constants.rs")
blocks = [f"// RFC 6330 tables, adapted from cberner/raptorq (Apache-2.0).\n// Reference commit {REVISION}.\n"]
for index in range(4):
    match = re.search(rf"const V{index}: \[u32; 256\] = \[(.*?)\];", rng, re.S)
    values = list(map(int, re.findall(r"\d+", match.group(1))))
    assert len(values) == 256
    blocks.append(f"///|\nlet random_v{index} : Array[UInt] = [\n" + "\n".join(f"  {value}U," for value in values) + "\n]")
table = parameters.split("= [", 1)[1].split("];", 1)[0]
rows = [tuple(map(int, row)) for row in re.findall(r"\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)", table)]
bounded = []
for row in rows:
    bounded.append(row)
    if row[0] >= 256: break
assert bounded[-1][0] == 257
blocks.append("///|\nlet systematic_parameters : Array[(Int, Int, Int, Int, Int)] = [\n" + "\n".join(f"  {row}," for row in bounded) + "\n]")
(ROOT / "standard_tables.mbt").write_text("\n\n".join(blocks) + "\n", encoding="utf-8")
subprocess.run(["moon", "fmt"], cwd=ROOT, check=True)
print(f"Generated four 256-entry Rand tables and {len(bounded)} parameter rows")
