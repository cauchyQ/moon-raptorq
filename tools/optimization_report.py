"""Compare retained before/after rows from this algorithm change."""
from pathlib import Path
import json
import statistics

root = Path(__file__).resolve().parents[1]
reports = root / 'reports'
def load(name):
    return [json.loads(line) for line in (reports / name).read_text(encoding='utf-8').splitlines() if line.startswith('{')]
before = load('optimization-before-scaling.jsonl')
after = load('scaling-wasm.jsonl')
def med(rows, k, width, key):
    return statistics.median(r[key] for r in rows if 'kind' not in r and r['K'] == k and r['T'] == width and r['repetition'] >= 0)
lines = ['# 算法检查与改进结果', '',
         '本轮保留同一台机器、同一工具链下修改前后的原始测量。Wasm，规模表每组三轮中位数，预热不计入；单位为毫秒。耗时会受到机器负载影响。', '',
         '## 检查结论与改动', '',
         '1. 完整源符号接收仍进入稠密消元。现在仅在恰好 K 个不同包且全部为源符号时，按 ESI 排序并直接拼接，decode 从 O(L³+L²T) 降为 O(KT)，不分配消元矩阵。包入库的去重扫描成本不在这个复杂度结论内。',
         '2. 行运算把系数 1 也当作一般 GF(256) 乘法。现在 0 跳过、1 直接 XOR，其余系数的乘法表行在循环外取得。',
         '3. 主元为 1 时仍遍历归一化。现在直接跳过，其他主元同样复用单行查表。批量与流式求解共用该内核。',
         '4. 收齐源符号后还有额外修复方程时，仍走正常消元，检查多余方程的一致性；没有以快速返回掩盖冲突。', '',
         '## 仅源符号的 decode', '', '| K | 改前 | 改后 | 改前/改后 |', '| ---: | ---: | ---: | ---: |']
b = load('optimization-before-systematic.jsonl')
a = load('optimization-after-systematic.jsonl')
for k in [16,64,256]:
    old = med(b,k,128,'decode_us'); new = med(a,k,128,'decode_us')
    lines.append(f'| {k} | {old/1000:.4f} | {new/1000:.4f} | {old/new:.2f}× |')
lines += ['', '该表只计入 decode，包生成、接收、去重和进程启动均不计入；不能当作端到端传输加速比。五轮中位数。', '',
          '## 仅修复符号路径', '', '| K | T | 直接编码前→后 | 批量解码前→后 | 流式解码前→后 |', '| ---: | ---: | ---: | ---: | ---: |']
for k in [16,64,128,256]:
    for width in [8,128,1024]:
        cells = []
        for key in ['direct_encoder_us','batch_decode_us','stream_decode_us']:
            old=med(before,k,width,key); new=med(after,k,width,key)
            cells.append(f'{old/1000:.3f}→{new/1000:.3f}')
        lines.append(f'| {k} | {width} | ' + ' | '.join(cells) + ' |')
lines += ['', '修复路径仍使用有界稠密消元，最坏复杂度未改变。没有实现或宣称稀疏失活译码；完整 RFC 参数范围仍未开放。全部规模和不占优的数据均保留。', '',
          '## 正确性验证', '',
          '新增测试穷举所有 256 个行运算系数，与独立多项式运算比较；另测试乱序源符号、尾部补零、重复 decode 和额外损坏修复包。全量测试、三后端示例及独立 Rust 互操作由 tools/check.py 与 tools/verify_interop.py 记录。', '']
(reports/'OPTIMIZATION.md').write_text('\n'.join(lines),encoding='utf-8')
print('\n'.join(lines[12:20]))
