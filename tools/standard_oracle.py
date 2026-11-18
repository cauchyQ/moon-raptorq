"""Independent exact repair bytes from pinned Rust raptorq 2.0.0."""
import json
import sys
from pathlib import Path
from reference_oracle import raptorq

if len(sys.argv) > 1:
    cases = json.loads(Path(sys.argv[1]).read_text())
    for case in cases:
        k = case['k']
        decoder = raptorq.Decoder.with_defaults(k, 1)
        recovered = None
        for i in range(k):
            if i % 10:
                recovered = decoder.decode(b'\x00' + i.to_bytes(3,'big') + bytes([(i*17+11)%256])) or recovered
        for j, payload in enumerate(bytes.fromhex(case['repairs_hex'])):
            recovered = decoder.decode(b'\x00' + (k+j).to_bytes(3,'big') + bytes([payload])) or recovered
        assert bytes(recovered) == bytes((i*17+11)%256 for i in range(k))
    print(json.dumps(dict(reverse='PASS', cases=len(cases))))
    raise SystemExit(0)
result = []
for k in [257, 1024, 4096, 56403]:
    data = bytes((i * 17 + 11) % 256 for i in range(k))
    encoder = raptorq.Encoder.with_defaults(data, 1)
    repairs = {}
    for packet in encoder.get_encoded_packets((k+9)//10+16):
        packet = bytes(packet)
        esi = int.from_bytes(packet[1:4], "big")
        if esi >= k:
            repairs[esi] = packet[4:].hex()
    assert k in repairs, (k, repairs)
    result.append(dict(k=k, t=1, repair=repairs[k], repairs_hex="".join(repairs[i] for i in range(k,k+(k+9)//10+16))))
print(json.dumps(result))
