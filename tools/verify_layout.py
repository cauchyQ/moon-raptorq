"""Bidirectional non-default layout verification; generated fixtures excluded from LOC."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
from verify_standard import oracle as standard_oracle


def oracle(*paths):
    return standard_oracle(*paths, script_name='layout_oracle.py')


cases = oracle()
tests = ['// Generated independent Python-layout / Rust-codec vectors. Not handwritten LOC.']
for i, case in enumerate(cases):
    f, t, z, n, al = (case[k] for k in ['f', 't', 'z', 'n', 'al'])
    body = [f'///|\ntest "independent aligned layout {i}" {{',
            f'  let info = @moon-raptorq.TransmissionInfo::new({f}L, {t}, {z}, {n}, {al}).unwrap()',
            '  let output = @buffer.Buffer::Buffer()']
    for block, encoded in enumerate(case['blocks']):
        body += ['  {', f'    let decoder = @moon-raptorq.StandardBlockDecoder::new({encoded["k"]}, {t}).unwrap()',
                 '    let packets = [', *[f'      "{p}",' for p in encoded['repairs']], '    ]',
                 '    for raw in packets {', '      let bytes = @hex.decode(raw)',
                 '      let id = bytes[1].to_int() * 65536 + bytes[2].to_int() * 256 + bytes[3].to_int()',
                 '      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore', '    }',
                 f'    output.write_bytes(info.reassemble_block({block}, decoder.decode().unwrap().unwrap()).unwrap()[:])',
                 '  }']
    body += [f'  assert_eq(output.to_bytes(), @hex.decode("{case["data"]}"))', '}']
    tests.append('\n'.join(body))
(ROOT / 'standard_layout_vectors_test.mbt').write_text('\n\n'.join(tests) + '\n', encoding='utf-8')
subprocess.run(['moon', 'fmt'], cwd=ROOT, check=True)
subprocess.run(['moon', 'test', '--release', '--deny-warn'], cwd=ROOT, check=True)
output = subprocess.check_output(['moon', 'run', 'cmd/layout-interop', '--release'], cwd=ROOT, text=True, encoding='utf-8')
export = ROOT / '.verification/layout-packets.json'
export.parent.mkdir(exist_ok=True)
export.write_text(output, encoding='utf-8')
report = dict(reference='Rust raptorq 2.0.0 + independent Python RFC layout',
              rust_to_moonbit='PASS', reverse=oracle(export),
              profiles=[{k: c[k] for k in ['f', 't', 'z', 'n', 'al']} for c in cases],
              fixture_sha256=hashlib.sha256(json.dumps(cases, sort_keys=True).encode()).hexdigest())
(ROOT / 'reports/layout-interop.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
