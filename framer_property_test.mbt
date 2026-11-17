///|
test "random stream chunking preserves exact packet order and duplicate IDs" {
  let source = test_data(251, 13U)
  let encoder = @moon-raptorq.Encoder::new(source, 11).unwrap()
  let packets : Array[@moon-raptorq.Packet] = []
  for id in 0..<40 {
    let packet = encoder.packet(id).unwrap()
    packets.push(packet)
    if id % 7 == 0 {
      packets.push(packet)
    }
  }
  let stream = concatenated(packets)
  for trial in 0..<32 {
    let framer = @moon-raptorq.PacketFramer::new(encoder.config()).unwrap()
    let decoded : Array[@moon-raptorq.Packet] = []
    let mut state = (trial + 1).reinterpret_as_uint()
    let mut cursor = 0
    while cursor < stream.length() {
      state = state * 1664525U + 1013904223U
      let desired = (state % 89U).reinterpret_as_int() + 1
      let remaining = stream.length() - cursor
      let size = if desired < remaining { desired } else { remaining }
      assert_eq(framer.push(b"").unwrap().length(), 0)
      for
        packet in framer.push(stream[cursor:cursor + size].to_owned()).unwrap() {
        decoded.push(packet)
      }
      cursor += size
    }
    assert_eq(framer.finish().unwrap(), packets.length())
    assert_eq(decoded.length(), packets.length())
    for i in 0..<packets.length() {
      assert_eq(decoded[i].serialize(), packets[i].serialize())
    }
  }
}

///|
test "a rejected chunk is retryable at every prefix of a valid stream" {
  let config = @moon-raptorq.Config::new(4, 4).unwrap()
  let packets = [
    @moon-raptorq.Packet::new(0, b"abcd").unwrap(),
    @moon-raptorq.Packet::new(1, b"efgh").unwrap(),
    @moon-raptorq.Packet::new(2, b"ijkl").unwrap(),
  ]
  let stream = concatenated(packets)
  for prefix in 0..<16 {
    let framer = @moon-raptorq.PacketFramer::new(config).unwrap()
    let parsed = framer.push(stream[:prefix].to_owned()).unwrap()
    let buffered = framer.buffered()
    let completed = framer.parsed()
    let suffix = stream[prefix:].to_owned()
    // The third packet always begins in this suffix, so the bad block byte
    // must be checked even if the chunk also completes earlier valid frames.
    let damaged = changed(suffix, 16 - prefix, 255)
    assert_true(framer.push(damaged) is Err(_))
    assert_eq(framer.buffered(), buffered)
    assert_eq(framer.parsed(), completed)
    for packet in framer.push(suffix).unwrap() {
      parsed.push(packet)
    }
    assert_eq(parsed.length(), 3)
    for i in 0..<3 {
      assert_eq(parsed[i].serialize(), packets[i].serialize())
    }
    assert_eq(framer.finish().unwrap(), 3)
  }
}

///|
test "maximum width packet framing does not require a whole stream buffer" {
  let data = test_data(4096, 5U)
  let packet = @moon-raptorq.Packet::new(16777215, data).unwrap()
  let config = @moon-raptorq.Config::new(1, 4096).unwrap()
  let framer = @moon-raptorq.PacketFramer::new(config, max_packets=65536).unwrap()
  let bytes = packet.serialize()
  assert_eq(framer.push(bytes[:4099].to_owned()).unwrap().length(), 0)
  assert_eq(framer.buffered(), 4099)
  let parsed = framer.push(bytes[4099:].to_owned()).unwrap()
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].serialize(), bytes)
  assert_eq(framer.buffered(), 0)
  assert_eq(framer.finish().unwrap(), 1)
}
