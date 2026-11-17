"""Generate independent Rust fixtures and run exact symbol-byte comparisons."""
from pathlib import Path
import json
import os
import subprocess
import sys
import hashlib

ROOT = Path(__file__).resolve().parents[1]
def oracle(*arguments):
    script = ROOT / "tools/reference_oracle.py"
    if os.name == "nt":
        def linux(path):
            path = str(path.resolve()).replace("\\", "/")
            return "/mnt/" + path[0].lower() + path[2:]
        cmd = ["wsl", "-e", "python3", linux(script), *[x if str(x).startswith("--") else linux(Path(x)) for x in arguments]]
    else:
        cmd = [sys.executable, str(script), *map(str, arguments)]
    return subprocess.check_output(cmd, text=True, encoding="utf-8", cwd=ROOT)

cases = json.loads(oracle())
target = ROOT / "reference_vectors_test.mbt"
blocks = ["// Generated Rust raptorq 2.0.0 fixtures. Not handwritten implementation.\n"]
def literal(hexdata):
    return f'@hex.decode("{hexdata}")'
for case in cases:
    packets = case["packets"]
    # All systematic packets and all repairs are byte-compared with the independent encoder.
    body = [f'///|\ntest "Rust vector K{case["k"]}" {{',
            f'  let source = {literal(case["data"])}',
            f'  let encoder = @moon-raptorq.Encoder::new(source, {case["size"]}).unwrap()',
            '  let receiver = @moon-raptorq.Decoder::new(encoder.config())']
    body += ['  let packets = [', *[f'    "{p}",' for p in packets], '  ]']
    body += ['  for raw in packets {',
             '    let expected = encoder.config().parse_packet(@hex.decode(raw)).unwrap()',
             '    let packet = encoder.packet(expected.id()).unwrap()',
             '    assert_eq(packet.serialize(), expected.serialize())',
             f'    if packet.id() >= {case["k"]} || packet.id() % 3 != 0 {{',
             '      ignore(receiver.push(expected).unwrap())', '    }', '  }']
    body += ['  assert_eq(receiver.decode().unwrap(), Some(source))', '}']
    blocks.append('\n'.join(body))
object_cases = json.loads(oracle("--objects"))
for index, case in enumerate(object_cases):
    body = [f'///|\ntest "Rust object partition vector {index}" {{',
            f'  let data = {literal(case["data"])}',
            f'  let config = @moon-raptorq.ObjectConfig::new(data.length(), {case["size"]}, {case["blocks"]}).unwrap()',
            '  let decoder = @moon-raptorq.ObjectDecoder::new(config).unwrap()',
            '  let packets = [', *[f'    "{p}",' for p in case["packets"]], '  ]',
            '  for packet in packets.rev() { ignore(decoder.push_bytes(@hex.decode(packet)).unwrap()) }',
            '  assert_eq(decoder.decode(), Some(data))', '}']
    blocks.append('\n'.join(body))
target.write_text('\n\n'.join(blocks), encoding='utf-8')
subprocess.run(["moon", "fmt"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
subprocess.run(["moon", "test", "--release", "--deny-warn"], cwd=ROOT, check=True)
print(f"Rust -> MoonBit and exact encoder bytes: {len(cases)} profiles PASS")
output = subprocess.check_output(["moon", "run", "cmd/interop", "--release"], cwd=ROOT, text=True, encoding="utf-8")
moon_cases = json.loads(output)
assert len(moon_cases) == len(cases)
export = ROOT / ".verification/moonbit-packets.json"
export.parent.mkdir(exist_ok=True)
export.write_text(output, encoding="utf-8")
reverse = json.loads(oracle(export))
print(json.dumps(reverse))
objects = subprocess.check_output(["moon", "run", "cmd/object-interop", "--release"], cwd=ROOT, text=True, encoding="utf-8")
object_export = ROOT / ".verification/moonbit-objects.json"
object_export.write_text(objects, encoding="utf-8")
print(oracle(object_export).strip())
report = dict(
    reference="Rust raptorq 2.0.0 Python binding (PyPI Linux abi3 wheel)",
    profiles=[case["k"] for case in cases],
    symbol_size=8,
    reference_packets=sum(len(case["packets"]) for case in cases),
    moonbit_packets=sum(len(case["packets"]) for case in moon_cases),
    reference_fixture_sha256=hashlib.sha256(json.dumps(cases, sort_keys=True).encode()).hexdigest(),
    exact_wire_bytes="PASS", rust_to_moonbit="PASS", moonbit_to_rust="PASS",
    erasure_pattern="drop ESI divisible by 3 from systematic set; add ceil(K/3)+8 repairs",
    multi_block_cases=len(object_cases),
    multi_block_scope="RFC Partition computed separately in Python; each block checked with Rust single-block encoder/decoder. Rust Python API does not expose custom multi-block OTI.",
)
(ROOT / "reports").mkdir(exist_ok=True)
(ROOT / "reports/interop.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
