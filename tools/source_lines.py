"""Transparent source accounting: generated RFC data and fixtures are separate."""
from pathlib import Path
from collections import defaultdict
import json

root = Path(__file__).resolve().parents[1]
skip = {".git", ".mooncakes", "_build", "target", ".verification"}
totals = defaultdict(lambda: dict(files=0, physical=0, nonblank_noncomment=0))
files = []
for path in sorted(root.rglob("*.mbt")):
    relative = path.relative_to(root)
    if any(part in skip for part in relative.parts):
        continue
    name = path.name
    if name == "standard_tables.mbt": category = "generated_standard_data"
    elif name in {"reference_vectors_test.mbt", "standard_layout_vectors_test.mbt"}: category = "generated_reference_fixtures"
    elif name.endswith("_bench.mbt"): category = "handwritten_experiments"
    elif name.endswith(("_test.mbt", "_wbtest.mbt")): category = "handwritten_tests"
    elif relative.parts[0] in {"lab", "benchmarks"}: category = "handwritten_experiments"
    elif relative.parts[0] in {"examples", "cmd"}: category = "handwritten_examples_cli"
    else: category = "handwritten_library"
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    count = sum(bool(line.strip()) and not line.lstrip().startswith("//") for line in lines)
    record = dict(path=str(relative).replace("\\", "/"), category=category, physical=len(lines), nonblank_noncomment=count)
    files.append(record)
    totals[category]["files"] += 1
    totals[category]["physical"] += len(lines)
    totals[category]["nonblank_noncomment"] += count
report = dict(method="Physical lines plus nonblank lines not starting //; not an AST complexity measure.", categories=dict(totals), files=files)
(root / "reports").mkdir(exist_ok=True)
(root / "reports/source-lines.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(dict(totals), indent=2))
print("handwritten physical:", sum(v["physical"] for k, v in totals.items() if k.startswith("handwritten")))
