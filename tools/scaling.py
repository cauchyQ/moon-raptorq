"""Record bounded-profile scaling and observed repair-only rank overhead."""
from pathlib import Path
import json
import statistics
import subprocess

root = Path(__file__).resolve().parents[1]
raw = subprocess.check_output(["moon", "run", "benchmarks/scaling", "--release"], cwd=root, text=True, encoding="utf-8")
rows = [json.loads(line) for line in raw.splitlines() if line.startswith("{")]
assert len(rows) == 240, len(rows)
(root / "reports/scaling-wasm.jsonl").write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")
lines = ["# 有界规模与修复开销测量", "", "Wasm，时间为毫秒，三轮中位数；另有一轮预热不计入统计。", "",
         "| K | T | 直接编码 | 建立计划 | 复用计划编码 | 批量解码 | 流式解码 | 原始存储上界字节 |",
         "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
for k in [16, 64, 128, 256]:
    for width in [8, 128, 1024]:
        selected = [r for r in rows if "kind" not in r and r["K"] == k and r["T"] == width and r["repetition"] >= 0]
        def median(key): return statistics.median(r[key] for r in selected) / 1000
        lines.append(f"| {k} | {width} | {median('direct_encoder_us'):.3f} | {median('plan_build_us'):.3f} | {median('planned_encoder_us'):.3f} | {median('batch_decode_us'):.3f} | {median('stream_decode_us'):.3f} | {selected[0]['stream_raw_storage_bound']} |")
lines += ["", "计划建立与计划复用分别计时；复用计划会增加系数存储。表中存储为代码结构估算，不是实测 RSS。解码仅接收 K+8 个修复符号，没有源符号。", "",
          "## 仅修复符号的观察成功率", "", "每个 K 取 64 个固定种子和不同起始 ESI；这不是协议的全局失败概率证明。", "",
          "| K | K 包 | K+1 包 | K+2 包 | K+4 包 | K+8 包 |", "| ---: | ---: | ---: | ---: | ---: | ---: |"]
for k in [16, 32, 64]:
    selected = [r for r in rows if r.get("kind") == "repair-only-overhead" and r["K"] == k]
    rates = []
    for extra in [0, 1, 2, 4, 8]:
        successes = sum(any(p["extra"] == extra and p["rank"] == k for p in r["checkpoints"]) for r in selected)
        rates.append(f"{successes}/64")
    lines.append(f"| {k} | " + " | ".join(rates) + " |")
lines += ["", "统计不预设恰好 K 包一定能恢复。本库用独立秩判断是否完成，不能用收包数代替秩。", ""]
(root / "reports/SCALING.md").write_text("\n".join(lines), encoding="utf-8")
print("48 scaling measurements (12 warmups), 192 repair-only trials recorded")
