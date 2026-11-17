///|
fn concatenated(packets : Array[@moon-raptorq.Packet]) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  for packet in packets {
    out.write_bytes(packet.serialize()[:])
  }
  out.to_bytes()
}

///|
test "packet framer handles every two chunk boundary" {
  let encoder = @moon-raptorq.Encoder::new(b"framed symbol stream", 3).unwrap()
  let packets = [
    encoder.packet(1).unwrap(),
    encoder.packet(10).unwrap(),
    encoder.packet(65536).unwrap(),
  ]
  let bytes = concatenated(packets)
  for split in 0..<(bytes.length() + 1) {
    let framer = @moon-raptorq.PacketFramer::new(encoder.config()).unwrap()
    let parsed = framer.push(bytes[:split].to_owned()).unwrap()
    for packet in framer.push(bytes[split:].to_owned()).unwrap() {
      parsed.push(packet)
    }
    assert_eq(parsed.length(), packets.length())
    for i in 0..<packets.length() {
      assert_eq(parsed[i].serialize(), packets[i].serialize())
    }
    assert_eq(framer.buffered(), 0)
    assert_eq(framer.parsed(), 3)
    assert_eq(framer.finish().unwrap(), 3)
  }
}

///|
test "single byte framing feeds a repair only streaming decoder" {
  let source = test_data(83, 8U)
  let encoder = @moon-raptorq.Encoder::new(source, 7).unwrap()
  let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
  let framer = @moon-raptorq.PacketFramer::new(encoder.config(), max_packets=24).unwrap()
  let packets : Array[@moon-raptorq.Packet] = []
  for id in 12..<36 {
    packets.push(encoder.packet(id).unwrap())
  }
  let bytes = concatenated(packets)
  for position in 0..<bytes.length() {
    for packet in framer.push(bytes[position:position + 1].to_owned()).unwrap() {
      ignore(receiver.push(packet).unwrap())
    }
    assert_true(framer.buffered() >= 0 && framer.buffered() < 11)
  }
  assert_eq(framer.finish().unwrap(), 24)
  assert_eq(receiver.decode().unwrap(), Some(source))
}

///|
test "framer rejects foreign blocks atomically and accepts a valid retry" {
  let config = @moon-raptorq.Config::new(4, 4).unwrap()
  let framer = @moon-raptorq.PacketFramer::new(config).unwrap()
  let first = @moon-raptorq.Packet::new(0, b"abcd").unwrap()
  let second = @moon-raptorq.Packet::new(1, b"efgh").unwrap()
  let good = concatenated([first, second])
  assert_true(
    framer.push(changed(good, 8, 1)) is Err(@moon-raptorq.UnsupportedProfile(_)),
  )
  assert_eq(framer.parsed(), 0)
  assert_eq(framer.buffered(), 0)
  assert_eq(framer.push(good).unwrap().length(), 2)
  assert_eq(framer.parsed(), 2)
}

///|
test "framer rollback preserves a partial prefix" {
  let config = @moon-raptorq.Config::new(2, 2).unwrap()
  let framer = @moon-raptorq.PacketFramer::new(config).unwrap()
  let packet = @moon-raptorq.Packet::new(9, b"ab").unwrap().serialize()
  assert_eq(framer.push(packet[:3].to_owned()).unwrap().length(), 0)
  let out = @buffer.Buffer::Buffer()
  out.write_bytes(packet[3:])
  out.write_bytes(b"\x01\x00\x00\x00xx")
  assert_true(framer.push(out.to_bytes()) is Err(_))
  assert_eq(framer.buffered(), 3)
  assert_eq(framer.parsed(), 0)
  let parsed = framer.push(packet[3:].to_owned()).unwrap()
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].serialize(), packet)
}

///|
test "framer capacity partial suffix finish and sealed state" {
  let config = @moon-raptorq.Config::new(1, 1).unwrap()
  for limit in [0, -1, 65537, 2147483647] {
    assert_true(
      @moon-raptorq.PacketFramer::new(config, max_packets=limit) is Err(_),
    )
  }
  let framer = @moon-raptorq.PacketFramer::new(config, max_packets=1).unwrap()
  assert_eq(framer.push(b"").unwrap().length(), 0)
  assert_true(framer.push(b"123456") is Err(@moon-raptorq.ResourceLimit(_)))
  assert_eq(framer.buffered(), 0)
  assert_eq(framer.push(b"\x00\x00").unwrap().length(), 0)
  assert_true(framer.finish() is Err(@moon-raptorq.InvalidPacket(_)))
  assert_eq(framer.buffered(), 2)
  assert_true(framer.push(b"1234") is Err(@moon-raptorq.ResourceLimit(_)))
  assert_eq(framer.buffered(), 2)
  assert_eq(framer.push(b"\x00\x00x").unwrap().length(), 1)
  assert_true(framer.push(b"x") is Err(@moon-raptorq.ResourceLimit(_)))
  assert_eq(framer.finish().unwrap(), 1)
  assert_eq(framer.finish().unwrap(), 1)
  assert_true(framer.push(b"") is Err(@moon-raptorq.InvalidPacket(_)))
}

///|
test "framer payloads are independent of reusable scratch storage" {
  let config = @moon-raptorq.Config::new(4, 4).unwrap()
  let framer = @moon-raptorq.PacketFramer::new(config).unwrap()
  let first = framer.push(b"\x00\x00\x00\x00abcd").unwrap()[0]
  let second = framer.push(b"\x00\x00\x00\x01wxyz").unwrap()[0]
  assert_eq(first.payload(), b"abcd")
  assert_eq(second.payload(), b"wxyz")
  assert_eq(framer.parsed(), 2)
}
