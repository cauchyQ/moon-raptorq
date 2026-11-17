"""Run identical traces through actual published MoonBit libraries; retain raw rows."""
from pathlib import Path
import json
import platform
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
REPORTS.mkdir(exist_ok=True)
targets = sys.argv[1:] or ["wasm", "js"]
all_rows = []
for target in targets:
    command = ["moon", "run", "benchmarks/compare", "--release", "--target", target]
    raw = subprocess.check_output(command, cwd=ROOT, text=True, encoding="utf-8")
    rows = [json.loads(line) for line in raw.splitlines() if line.startswith("{")]
    assert len(rows) == 192, (target, len(rows))
    for row in rows:
        row["target"] = target
        if row["repetition"] >= 0:
            all_rows.append(row)
    (REPORTS / f"comparison-{target}.jsonl").write_text(
        "\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n", encoding="utf-8"
    )
    print(f"{target}: {len(rows)} rows including warmup, {sum(r['recovered'] for r in rows)} exact recoveries")

groups = {}
for row in all_rows:
    key = (row["target"], row["scenario"], row["algorithm"])
    groups.setdefault(key, []).append(row)
summary = []
for (target, scenario, algorithm), rows in sorted(groups.items()):
    # Each multicast encode is shared by six receivers. Do not give that
    # encoding measurement six independent statistical votes.
    encoding = {row["repetition"]: row["encode_us"] for row in rows}
    summary.append(dict(
        target=target, scenario=scenario, algorithm=algorithm,
        observations=len(rows), successes=sum(row["recovered"] for row in rows),
        median_encode_us=statistics.median(encoding.values()),
        median_decode_us=statistics.median(row["decode_us"] for row in rows),
        min_decode_us=min(row["decode_us"] for row in rows),
        max_decode_us=max(row["decode_us"] for row in rows),
        sent_bytes=rows[0]["sent_bytes"],
        K=rows[0]["K"], T=rows[0]["T"], budget=rows[0]["budget"],
    ))

report = dict(
    platform=platform.platform(),
    python=sys.version.split()[0],
    moon=subprocess.check_output(["moon", "version", "--all"], text=True, encoding="utf-8").strip(),
    repetitions=5, warmup_repetitions=1, summaries=summary,
    timing="monotonic microseconds, in-process; no compile or process startup",
    dependencies={"oyjh0381/moonerasure": "0.3.0", "ZJH-666-ZJH/moonrecoder": "0.1.1"},
)
(REPORTS / "comparison-summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
lines = ["# 实际对照测量", "", "以下内容由 tools/benchmark.py 从原始测量自动汇总，单位为毫秒。", "",
         "| 后端 | 场景 | 实际库 | 恢复成功 | 编码中位数 | 解码中位数 | 发送字节 |",
         "| --- | --- | --- | --- | ---: | ---: | ---: |"]
for row in summary:
    lines.append(f"| {row['target']} | {row['scenario']} | {row['algorithm']} | {row['successes']}/{row['observations']} | {row['median_encode_us']/1000:.3f} | {row['median_decode_us']/1000:.3f} | {row['sent_bytes']} |")
lines += ["", "原始数据包含预热行（repetition=-1），统计时剔除；每组五轮。组播编码一次供六个接收方使用。",
          "时间包含实际报文生成/解析，各协议的校验、元数据与保护能力不同，不能把字节差直接解释为同等安全保证下的压缩收益。",
          "MoonErasure 接收适配器先去重，去重耗时及重复报文字节均计入。此实验没有模拟完整网络协议、重传反馈、带宽竞争或真实设备。", ""]
(REPORTS / "MEASUREMENTS.md").write_text("\n".join(lines), encoding="utf-8")
failures = [row for row in all_rows if not row["recovered"]]
(REPORTS / "nonrecoveries.json").write_text(json.dumps(failures, indent=2) + "\n", encoding="utf-8")
print(f"Observed {len(failures)} nonrecoveries; raw ranks and seeds are retained in nonrecoveries.json")
if any(row["algorithm"].startswith("MoonRaptorQ") for row in failures):
    raise SystemExit("The tested MoonRaptorQ profiles failed this bounded experiment.")
