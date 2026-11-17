///|
test "object framer demultiplexes source block numbers across chunk boundaries" {
  let data = test_data(71, 21U)
  let encoder = @moon-raptorq.ObjectEncoder::new(data, 3, 3).unwrap()
  let reader = @moon-raptorq.ObjectFramer::new(encoder.config()).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(
    encoder.config(),
    max_active_blocks=3,
  ).unwrap()
  let blocks = [
    encoder.block(0).unwrap(),
    encoder.block(1).unwrap(),
    encoder.block(2).unwrap(),
  ]
  let bytes = @buffer.Buffer::Buffer()
  for id in 0..<16 {
    for index in [2, 0, 1] {
      bytes.write_bytes(
        encoder
        .config()
        .packet(index, blocks[index].packet(id).unwrap())
        .unwrap()
        .serialize()[:],
      )
    }
  }
  let stream = bytes.to_bytes()
  let mut cursor = 0
  let mut chunk = 0
  while cursor < stream.length() {
    let desired = 1 + chunk % 19
    let remaining = stream.length() - cursor
    let count = if desired < remaining { desired } else { remaining }
    for packet in reader.push(stream[cursor:cursor + count].to_owned()).unwrap() {
      ignore(receiver.push(packet).unwrap())
    }
    cursor += count
    chunk += 1
  }
  assert_eq(reader.finish().unwrap(), 48)
  assert_eq(reader.parsed(), 48)
  assert_eq(reader.buffered(), 0)
  assert_eq(receiver.decode(), Some(data))
}

///|
test "object framer rollback and packet budgets share single block semantics" {
  let config = @moon-raptorq.ObjectConfig::new(12, 2, 3).unwrap()
  for limit in [0, -1, 65537] {
    assert_true(
      @moon-raptorq.ObjectFramer::new(config, max_packets=limit) is Err(_),
    )
  }
  let reader = @moon-raptorq.ObjectFramer::new(config, max_packets=2).unwrap()
  assert_eq(reader.push(b"\x02\x00").unwrap().length(), 0)
  assert_eq(reader.buffered(), 2)
  assert_true(reader.finish() is Err(_))
  // Complete a valid first frame and then include an out-of-object block.
  assert_true(reader.push(b"\x00\x00ab\x03\x00\x00\x00cd") is Err(_))
  assert_eq(reader.buffered(), 2)
  assert_eq(reader.parsed(), 0)
  let parsed = reader.push(b"\x00\x00ab\x01\x00\x00\x01cd").unwrap()
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].block(), 2)
  assert_eq(parsed[1].block(), 1)
  assert_eq(parsed[0].symbol().payload(), b"ab")
  assert_eq(parsed[1].symbol().payload(), b"cd")
  assert_eq(reader.finish().unwrap(), 2)
  assert_true(reader.push(b"") is Err(_))
}

///|
test "every source block including block fifteen survives wire roundtrip" {
  let config = @moon-raptorq.ObjectConfig::new(16, 1, 16).unwrap()
  let reader = @moon-raptorq.ObjectFramer::new(config).unwrap()
  let packets = @buffer.Buffer::Buffer()
  for index in 0..<16 {
    let symbol = @moon-raptorq.Packet::new(16777215 - index, b"x").unwrap()
    packets.write_bytes(config.packet(index, symbol).unwrap().serialize()[:])
  }
  let parsed = reader.push(packets.to_bytes()).unwrap()
  assert_eq(parsed.length(), 16)
  for index in 0..<16 {
    assert_eq(parsed[index].block(), index)
    assert_eq(parsed[index].symbol().id(), 16777215 - index)
  }
  assert_eq(reader.finish().unwrap(), 16)
}
