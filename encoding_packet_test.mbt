///|
test "receiver accepts aggregated source and repair packets" {
  let info = @moon-raptorq.TransmissionInfo::new(12L, 3, 1, 1, 1).unwrap()
  let source = [b"abc", b"def", b"ghi", b"jkl"]
  let encoder = @moon-raptorq.StandardBlockEncoder::new(source).unwrap()
  let receiver = @moon-raptorq.StandardBlockDecoder::new(4, 3).unwrap()
  let packet = info
    .encoding_packet(
      0,
      4,
      Array::makei(12, i => encoder.symbol(4 + i).unwrap()),
    )
    .unwrap()
  let parsed = info.parse_encoding_packet(packet.serialize()).unwrap()
  assert_eq(parsed.first_esi(), 4)
  assert_eq(parsed.source_block(), 0)
  assert_eq(receiver.push_packet(parsed).unwrap(), 12)
  assert_eq(receiver.push_packet(parsed).unwrap(), 0)
  assert_eq(receiver.decode().unwrap(), Some(source))
  let first = info.encoding_packet(0, 0, source).unwrap()
  assert_eq(first.symbols(), source)
  assert_true(info.encoding_packet(0, 3, [b"abc", b"def"]) is Err(_))
  assert_true(info.encoding_packet(0, 16777215, [b"abc", b"def"]) is Err(_))
  assert_true(info.parse_encoding_packet(b"\x00\x00\x00\x00") is Err(_))
  assert_true(info.parse_encoding_packet(b"\x00\x00\x00\x00a") is Err(_))
}

///|
test "conflicting aggregate rejects its entire prefix" {
  let info = @moon-raptorq.TransmissionInfo::new(6L, 3, 1, 1, 1).unwrap()
  let receiver = @moon-raptorq.StandardBlockDecoder::new(2, 3).unwrap()
  receiver.push(1, b"def").unwrap() |> ignore
  let bad = info.encoding_packet(0, 0, [b"abc", b"BAD"]).unwrap()
  assert_true(receiver.push_packet(bad) is Err(_))
  assert_true(receiver.decode().unwrap() is None)
  assert_true(receiver.push(0, b"abc").unwrap())
  assert_eq(receiver.decode().unwrap(), Some([b"abc", b"def"]))
}
