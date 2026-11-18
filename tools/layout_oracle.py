"""RFC sub-block layout independently composed with pinned Rust block codecs."""
import json
from pathlib import Path
import sys
from reference_oracle import raptorq


def parts(length, size, blocks, subblocks, alignment):
    total = (length + size - 1) // size
    small, large = divmod(total, blocks)
    unit, extra = divmod(size // alignment, subblocks)
    widths = [(unit + (sub < extra)) * alignment for sub in range(subblocks)]
    data = bytes((i * 17 + 11) % 256 for i in range(length))
    offset = 0
    result = []
    for block in range(blocks):
        k = small + (block < large)
        raw = data[offset:offset + k * size].ljust(k * size, b'\0')
        symbols = [bytearray() for _ in range(k)]
        cursor = 0
        for width in widths:
            for symbol in symbols:
                symbol.extend(raw[cursor:cursor + width])
                cursor += width
        result.append((raw, [bytes(s) for s in symbols], widths))
        offset += k * size
    return data, result


if len(sys.argv) == 1:
    result = []
    for f, t, z, n, al in [(53, 12, 2, 3, 2), (101, 20, 3, 7, 4), (1025, 8, 4, 2, 1)]:
        data, blocks = parts(f, t, z, n, al)
        encoded = []
        for raw, symbols, _ in blocks:
            k = len(symbols)
            encoder = raptorq.Encoder.with_defaults(b''.join(symbols), t)
            repairs = [bytes(p).hex() for p in encoder.get_encoded_packets(k + 12)
                       if int.from_bytes(bytes(p)[1:4], 'big') >= k]
            encoded.append(dict(k=k, repairs=repairs))
        result.append(dict(f=f, t=t, z=z, n=n, al=al, data=data.hex(), blocks=encoded))
    print(json.dumps(result))
else:
    cases = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
    checked = 0
    for case in cases:
        data, blocks = parts(case['f'], case['t'], case['z'], case['n'], case['al'])
        recovered_object = bytearray()
        for actual, (raw, symbols, widths) in zip(case['blocks'], blocks, strict=True):
            t, k = case['t'], len(symbols)
            decoder = raptorq.Decoder.with_defaults(k * t, t)
            encoded = {bytes(p)[:4]: bytes(p) for p in
                       raptorq.Encoder.with_defaults(b''.join(symbols), t).get_encoded_packets(k + 12)}
            recovered = None
            for packet in actual:
                packet = bytes.fromhex(packet)
                assert packet == encoded[packet[:4]], 'MoonBit/Rust repair mismatch'
                recovered = decoder.decode(packet) or recovered
            assert bytes(recovered) == b''.join(symbols)
            reordered = bytearray()
            cursor = 0
            for width in widths:
                for symbol in range(k):
                    reordered.extend(recovered[symbol * t + cursor:symbol * t + cursor + width])
                cursor += width
            assert bytes(reordered) == raw
            recovered_object.extend(reordered)
            checked += 1
        assert recovered_object[:case['f']] == data
    print(json.dumps(dict(moonbit_to_rust='PASS', cases=len(cases), source_blocks=checked,
                         scope='Independent Python RFC layout plus Rust single-block codec; not Rust custom-OTI object API')))
