"""Rust raptorq 2.0.0 Python binding; no second implementation in this script."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / ".verification/reference-python2"))
import raptorq
from importlib.metadata import version
assert version("raptorq") == "2.0.0", "Reference must be pinned to raptorq==2.0.0"

def object_parts(data, size, blocks):
    total = (len(data) + size - 1) // size
    small, extra = divmod(total, blocks)
    cursor = 0
    result = []
    for block in range(blocks):
        count = small + (block < extra)
        result.append(data[cursor:cursor + count * size])
        cursor += count * size
    assert b"".join(result) == data
    return result

def object_fixtures():
    cases = []
    for length, size, blocks in [(53, 4, 3), (4101, 8, 3)]:
        data = source(1, length)
        packets = []
        for block, part in enumerate(object_parts(data, size, blocks)):
            k = (len(part) + size - 1) // size
            encoder = raptorq.Encoder.with_defaults(part, size)
            for raw in encoder.get_encoded_packets((k + 2) // 3 + 8):
                raw = bytes(raw)
                esi = int.from_bytes(raw[1:4], "big")
                if esi >= k or esi % 3 != 0:
                    packets.append((bytes([block]) + raw[1:]).hex())
        cases.append(dict(data=data.hex(), size=size, blocks=blocks, packets=packets))
    return cases

def verify_object(case):
    data = bytes.fromhex(case["data"])
    size = case["size"]
    blocks = case["blocks"]
    oti = len(data).to_bytes(5, "big") + b"\x00" + size.to_bytes(2, "big") + bytes([blocks, 0, 1, 1])
    assert case["oti"] == oti.hex()
    recovered = []
    for block, part in enumerate(object_parts(data, size, blocks)):
        k = (len(part) + size - 1) // size
        reference = {int.from_bytes(bytes(p)[1:4], "big"): bytes(p) for p in raptorq.Encoder.with_defaults(part, size).get_encoded_packets((k + 2) // 3 + 8)}
        decoder = raptorq.Decoder.with_defaults(len(part), size)
        decoded = None
        for raw in case["packets"]:
            raw = bytes.fromhex(raw)
            if raw[0] != block:
                continue
            single = b"\x00" + raw[1:]
            assert single == reference[int.from_bytes(single[1:4], "big")]
            value = decoder.decode(single)
            if value is not None:
                decoded = bytes(value)
        assert decoded == part
        recovered.append(decoded)
    assert b"".join(recovered) == data

def source(k, size, trim=0):
    return bytes((i * 17 + 11) % 256 for i in range(k * size - trim))

def fixtures():
    result = []
    for k in [1, 2, 3, 9, 10, 11, 16, 18, 32, 64, 128, 256]:
        size = 8
        data = source(k, size, 1 if k > 1 else 0)
        encoder = raptorq.Encoder.with_defaults(data, size)
        packets = encoder.get_encoded_packets((k + 2) // 3 + 8)
        result.append(dict(k=k, size=size, data=data.hex(), packets=[bytes(p).hex() for p in packets]))
    return result

if __name__ == "__main__":
    if sys.argv[1:] == ["--objects"]:
        print(json.dumps(object_fixtures()))
    elif len(sys.argv) == 1:
        print(json.dumps(fixtures()))
    else:
        cases = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
        for case in cases:
            if "blocks" in case:
                verify_object(case)
                continue
            expected = bytes.fromhex(case["data"])
            decoder = raptorq.Decoder.with_defaults(len(expected), case["size"])
            recovered = None
            for raw in case["packets"]:
                value = decoder.decode(bytes.fromhex(raw))
                if value is not None:
                    recovered = bytes(value)
            assert recovered == expected, case["k"]
        print(json.dumps(dict(direction="MoonBit -> Rust raptorq", cases=len(cases), result="PASS")))
