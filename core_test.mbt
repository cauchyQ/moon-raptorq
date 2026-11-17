///|
test "source symbols are systematic and repairs recover without sources" {
  let input = b"MoonBit RaptorQ sample with final padding."
  let encoder = @moon-raptorq.Encoder::new(input, 4).unwrap()
  let receiver = @moon-raptorq.Decoder::new(encoder.config())
  let count = encoder.config().source_symbols()
  for id in 0..<count {
    let payload = encoder.packet(id).unwrap().payload()
    for i in 0..<4 {
      if id * 4 + i < input.length() {
        assert_eq(payload[i], input[id * 4 + i])
      }
    }
  }
  assert_eq(receiver.decode().unwrap(), None)
  for id in count..<(count + 8) {
    ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
  }
  for id in (count + 8)..<(2 * count + 8) {
    ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_eq(receiver.decode().unwrap(), Some(input))
}

///|
test "wire framing roundtrips and rejects foreign profiles" {
  let config = @moon-raptorq.Config::new(123, 16).unwrap()
  assert_eq(
    @moon-raptorq.parse_config(config.serialize()).unwrap().transfer_length(),
    123,
  )
  let packet = @moon-raptorq.Packet::new(16777215, b"1234567890123456").unwrap()
  assert_eq(config.parse_packet(packet.serialize()).unwrap().id(), 16777215)
  assert_true(@moon-raptorq.Config::new(0, 1) is Err(_))
  assert_true(@moon-raptorq.Config::new(257, 1) is Err(_))
  assert_true(config.parse_packet(b"123") is Err(_))
}
