///|
test "RFC Partition assigns large blocks first and truncates only final padding" {
  let config = @moon-raptorq.ObjectConfig::new(30, 4, 3).unwrap()
  assert_eq(config.transfer_length(), 30)
  assert_eq(config.symbol_size(), 4)
  assert_eq(config.source_blocks(), 3)
  for
    (index, offset, length, k) in [(0, 0, 12, 3), (1, 12, 12, 3), (2, 24, 6, 2)] {
    assert_eq(config.block_offset(index).unwrap(), offset)
    let block = config.block_config(index).unwrap()
    assert_eq(block.transfer_length(), length)
    assert_eq(block.source_symbols(), k)
    assert_eq(block.symbol_size(), 4)
  }
  let exact = @moon-raptorq.ObjectConfig::new(32, 4, 4).unwrap()
  for index in 0..<4 {
    assert_eq(exact.block_offset(index).unwrap(), index * 8)
    assert_eq(exact.block_config(index).unwrap().transfer_length(), 8)
  }
}

///|
test "partition invariants hold across every block count and varied tails" {
  for blocks in 1..<17 {
    for k in [blocks, blocks + 1, blocks * 7 - 1, blocks * 256] {
      for tail in [1, 3, 7] {
        let length = (k - 1) * 7 + tail
        let config = @moon-raptorq.ObjectConfig::new(length, 7, blocks).unwrap()
        let mut cursor = 0
        let mut symbols = 0
        let mut previous_k = 257
        for index in 0..<blocks {
          let block = config.block_config(index).unwrap()
          assert_eq(config.block_offset(index).unwrap(), cursor)
          assert_true(block.source_symbols() <= previous_k)
          assert_true(block.source_symbols() >= k / blocks)
          assert_true(block.source_symbols() <= (k + blocks - 1) / blocks)
          if index < blocks - 1 {
            assert_eq(block.transfer_length() % 7, 0)
          }
          symbols += block.source_symbols()
          cursor += block.transfer_length()
          previous_k = block.source_symbols()
        }
        assert_eq(cursor, length)
        assert_eq(symbols, k)
      }
    }
  }
}

///|
test "object config validates both per block and total bounds" {
  for blocks in [-1, 0, 17, 2147483647] {
    assert_true(@moon-raptorq.ObjectConfig::new(1, 1, blocks) is Err(_))
  }
  assert_true(@moon-raptorq.ObjectConfig::new(1, 1, 2) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(257, 1, 1) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(4097, 1, 16) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(2147483647, 4096, 16) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(16777216, 4096, 16) is Ok(_))
  assert_true(@moon-raptorq.ObjectConfig::new(16777217, 4096, 16) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(1, 4097, 1) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(0, 1, 1) is Err(_))
  assert_true(@moon-raptorq.ObjectConfig::new(1, 0, 1) is Err(_))
  let config = @moon-raptorq.ObjectConfig::new(20, 4, 3).unwrap()
  for index in [-1, 3, 2147483647] {
    assert_true(config.block_offset(index) is Err(_))
    assert_true(config.block_config(index) is Err(_))
  }
}

///|
test "automatic block count uses the fewest supported blocks" {
  for
    (length, size, expected) in [
      (1, 1, 1),
      (256, 1, 1),
      (257, 1, 2),
      (4096, 1, 16),
      (1048576, 4096, 1),
      (1048577, 4096, 2),
    ] {
    let config = @moon-raptorq.ObjectConfig::automatic(length, size).unwrap()
    assert_eq(config.source_blocks(), expected)
  }
  for
    (length, size) in [
      (0, 1),
      (1, 0),
      (4097, 1),
      (2147483647, 1),
      (1, 2147483647),
    ] {
    assert_true(@moon-raptorq.ObjectConfig::automatic(length, size) is Err(_))
  }
}

///|
test "multi block OTI and packet headers are standard field layouts" {
  let config = @moon-raptorq.ObjectConfig::new(30, 4, 3).unwrap()
  assert_eq(
    config.serialize(),
    b"\x00\x00\x00\x00\x1e\x00\x00\x04\x03\x00\x01\x01",
  )
  let parsed = @moon-raptorq.parse_object_config(config.serialize()).unwrap()
  assert_eq(parsed.serialize(), config.serialize())
  let symbol = @moon-raptorq.Packet::new(65537, b"abcd").unwrap()
  let packet = config.packet(2, symbol).unwrap()
  assert_eq(packet.block(), 2)
  assert_eq(packet.symbol().id(), 65537)
  assert_eq(packet.serialize(), b"\x02\x01\x00\x01abcd")
  assert_eq(
    config.parse_packet(packet.serialize()).unwrap().serialize(),
    packet.serialize(),
  )
  assert_true(@moon-raptorq.parse_config(config.serialize()) is Err(_))
  for block in [-1, 3, 255] {
    assert_true(config.packet(block, symbol) is Err(_))
  }
  assert_true(
    config.packet(0, @moon-raptorq.Packet::new(1, b"x").unwrap()) is Err(_),
  )
  assert_true(config.parse_packet(b"\x03\x00\x00\x00abcd") is Err(_))
  assert_true(config.parse_packet(b"\x00\x00\x00\x00abc") is Err(_))
}

///|
test "multi block OTI parser rejects malformed fields without unsafe reads" {
  let oti = @moon-raptorq.ObjectConfig::new(30, 4, 3).unwrap().serialize()
  for length in 0..<12 {
    assert_true(
      @moon-raptorq.parse_object_config(oti[:length].to_owned()) is Err(_),
    )
  }
  for
    (offset, value) in [
      (0, 1),
      (1, 255),
      (5, 1),
      (8, 0),
      (8, 17),
      (9, 1),
      (10, 2),
      (11, 2),
    ] {
    assert_true(
      @moon-raptorq.parse_object_config(changed(oti, offset, value.to_byte()))
      is Err(_),
    )
  }
}

///|
test "one block object encoding agrees byte for byte with the original API" {
  let data = test_data(77, 3U)
  let direct = @moon-raptorq.Encoder::new(data, 8).unwrap()
  let object = @moon-raptorq.ObjectEncoder::new(data, 8, 1).unwrap()
  assert_eq(direct.config().serialize(), object.config().serialize())
  let block = object.block(0).unwrap()
  for id in [0, 9, 10, 32, 65536, 16777215] {
    let wrapped = object.config().packet(0, block.packet(id).unwrap()).unwrap()
    assert_eq(wrapped.serialize(), direct.packet(id).unwrap().serialize())
  }
  assert_true(object.block(1) is Err(_))
  assert_true(@moon-raptorq.ObjectEncoder::new(b"", 1, 1) is Err(_))
}

///|
test "multi block receiver releases completed bases and preserves object order" {
  let data = test_data(269, 4U)
  let encoder = @moon-raptorq.ObjectEncoder::new(data, 7, 3).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(
    encoder.config(),
    max_active_blocks=1,
  ).unwrap()
  assert_eq(receiver.decode(), None)
  for index in [2, 0, 1] {
    let source = encoder.block(index).unwrap()
    let k = source.config().source_symbols()
    assert_eq(receiver.block_progress(index).unwrap().independent, 0)
    for id in k..<(2 * k + 8) {
      let packet = encoder
        .config()
        .packet(index, source.packet(id).unwrap())
        .unwrap()
      ignore(receiver.push_bytes(packet.serialize()).unwrap())
    }
    assert_eq(receiver.active_blocks(), 0)
    assert_true(receiver.block_progress(index).unwrap().complete())
  }
  assert_eq(receiver.completed_blocks(), 3)
  assert_eq(receiver.decode(), Some(data))
  assert_eq(receiver.decode(), Some(data))
}

///|
test "interleaved blocks respect active budget and can retry after completion" {
  let data = test_data(95, 5U)
  let encoder = @moon-raptorq.ObjectEncoder::new(data, 4, 3).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(
    encoder.config(),
    max_active_blocks=1,
  ).unwrap()
  let a = encoder.block(0).unwrap()
  let b = encoder.block(1).unwrap()
  let c = encoder.block(2).unwrap()
  let packet = encoder.config().packet(0, a.packet(0).unwrap()).unwrap()
  assert_true(receiver.push(packet).unwrap())
  assert_false(receiver.push(packet).unwrap())
  assert_eq(receiver.active_blocks(), 1)
  let waiting = encoder.config().packet(1, b.packet(0).unwrap()).unwrap()
  assert_true(receiver.push(waiting) is Err(@moon-raptorq.ResourceLimit(_)))
  assert_eq(receiver.block_progress(1).unwrap().received, 0)
  for id in 1..<8 {
    ignore(
      receiver
      .push(encoder.config().packet(0, a.packet(id).unwrap()).unwrap())
      .unwrap(),
    )
  }
  assert_eq(receiver.active_blocks(), 0)
  assert_true(receiver.push(waiting).unwrap())
  for id in 1..<8 {
    ignore(
      receiver
      .push(encoder.config().packet(1, b.packet(id).unwrap()).unwrap())
      .unwrap(),
    )
  }
  for id in 0..<8 {
    ignore(
      receiver
      .push(encoder.config().packet(2, c.packet(id).unwrap()).unwrap())
      .unwrap(),
    )
  }
  assert_eq(receiver.completed_blocks(), 3)
  assert_eq(receiver.decode(), Some(data))
}

///|
test "completed object blocks ignore late packets and malformed input stays rejected" {
  let encoder = @moon-raptorq.ObjectEncoder::new(b"abcd", 4, 1).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(encoder.config()).unwrap()
  let packet = encoder
    .config()
    .packet(0, encoder.block(0).unwrap().packet(0).unwrap())
    .unwrap()
  assert_true(receiver.push(packet).unwrap())
  assert_eq(receiver.active_blocks(), 0)
  assert_false(receiver.push(packet).unwrap())
  assert_false(
    receiver
    .push(
      encoder
      .config()
      .packet(0, @moon-raptorq.Packet::new(0, b"xxxx").unwrap())
      .unwrap(),
    )
    .unwrap(),
  )
  assert_eq(receiver.decode(), Some(b"abcd"))
  assert_true(receiver.push_bytes(b"\x01\x00\x00\x00abcd") is Err(_))
  assert_true(receiver.push_bytes(b"short") is Err(_))
  assert_true(receiver.block_progress(-1) is Err(_))
  assert_true(receiver.block_progress(1) is Err(_))
  for limit in [0, -1, 17, 2147483647] {
    assert_true(
      @moon-raptorq.ObjectDecoder::new(
        encoder.config(),
        max_active_blocks=limit,
      )
      is Err(_),
    )
  }
}

///|
test "sixteen interleaved active blocks own independent state" {
  let data = test_data(63, 39U)
  let encoder = @moon-raptorq.ObjectEncoder::new(data, 2, 16).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(
    encoder.config(),
    max_active_blocks=16,
  ).unwrap()
  let blocks : Array[@moon-raptorq.Encoder] = []
  for index in 0..<16 {
    blocks.push(encoder.block(index).unwrap())
  }
  for index in 0..<16 {
    ignore(
      receiver
      .push(
        encoder
        .config()
        .packet(index, blocks[index].packet(0).unwrap())
        .unwrap(),
      )
      .unwrap(),
    )
    assert_eq(receiver.active_blocks(), index + 1)
  }
  assert_eq(receiver.completed_blocks(), 0)
  for index in 0..<16 {
    ignore(
      receiver
      .push(
        encoder
        .config()
        .packet(index, blocks[index].packet(1).unwrap())
        .unwrap(),
      )
      .unwrap(),
    )
    assert_eq(receiver.active_blocks(), 15 - index)
    assert_eq(receiver.completed_blocks(), index + 1)
  }
  assert_eq(receiver.decode(), Some(data))
}

///|
test "foreign symbol widths fail before allocating an object decoder block" {
  let config = @moon-raptorq.ObjectConfig::new(4, 4, 1).unwrap()
  let foreign = @moon-raptorq.ObjectConfig::new(2, 2, 1).unwrap()
  let receiver = @moon-raptorq.ObjectDecoder::new(config).unwrap()
  let packet = foreign
    .packet(0, @moon-raptorq.Packet::new(0, b"ab").unwrap())
    .unwrap()
  assert_true(receiver.push(packet) is Err(@moon-raptorq.InvalidPacket(_)))
  assert_eq(receiver.active_blocks(), 0)
  assert_eq(receiver.completed_blocks(), 0)
  assert_eq(receiver.block_progress(0).unwrap().received, 0)
}
