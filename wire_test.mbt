///|
fn changed(bytes : Bytes, offset : Int32, value : Byte) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  for index in 0..<bytes.length() {
    out.write_byte(if index == offset { value } else { bytes[index] })
  }
  out.to_bytes()
}

///|
test "config rejects invalid lengths and overflow sized arguments" {
  for length in [0, -1, -2147483648] {
    assert_true(
      @moon-raptorq.Config::new(length, 16)
      is Err(@moon-raptorq.InvalidParameters(_)),
    )
  }
  for size in [0, -1, -2147483648] {
    assert_true(
      @moon-raptorq.Config::new(1, size)
      is Err(@moon-raptorq.InvalidParameters(_)),
    )
  }
  for size in [4097, 65536, 2147483647] {
    assert_true(
      @moon-raptorq.Config::new(1, size) is Err(@moon-raptorq.ResourceLimit(_)),
    )
  }
  assert_true(@moon-raptorq.Config::new(2147483647, 4096) is Err(_))
  assert_true(@moon-raptorq.Config::new(1048577, 4096) is Err(_))
  assert_true(@moon-raptorq.Config::new(257, 1) is Err(_))
  assert_true(@moon-raptorq.Config::new(1048576, 4096) is Ok(_))
}

///|
test "config boundary lengths and rounding are exact" {
  for size in [1, 2, 3, 7, 128, 1024, 4096] {
    for k in [1, 2, 9, 10, 11, 32, 255, 256] {
      let exact = @moon-raptorq.Config::new(k * size, size).unwrap()
      assert_eq(exact.source_symbols(), k)
      assert_eq(exact.symbol_size(), size)
      assert_eq(exact.transfer_length(), k * size)
      let tail = @moon-raptorq.Config::new((k - 1) * size + 1, size).unwrap()
      assert_eq(tail.source_symbols(), k)
      assert_true(@moon-raptorq.Config::new(256 * size + 1, size) is Err(_))
    }
  }
}

///|
test "OTI canonical bytes follow RFC field positions" {
  let config = @moon-raptorq.Config::new(12345, 1024).unwrap()
  assert_eq(
    config.serialize(),
    b"\x00\x00\x00\x30\x39\x00\x04\x00\x01\x00\x01\x01",
  )
  let max = @moon-raptorq.Config::new(1048576, 4096).unwrap()
  assert_eq(
    max.serialize(),
    b"\x00\x00\x10\x00\x00\x00\x10\x00\x01\x00\x01\x01",
  )
  let min = @moon-raptorq.Config::new(1, 1).unwrap()
  assert_eq(
    min.serialize(),
    b"\x00\x00\x00\x00\x01\x00\x00\x01\x01\x00\x01\x01",
  )
}

///|
test "OTI roundtrip for every K and varied alignment free symbol sizes" {
  for k in 1..<257 {
    for size in [1, 3, 128, 4096] {
      let original = @moon-raptorq.Config::new((k - 1) * size + 1, size).unwrap()
      let parsed = @moon-raptorq.parse_config(original.serialize()).unwrap()
      assert_eq(parsed.transfer_length(), original.transfer_length())
      assert_eq(parsed.symbol_size(), size)
      assert_eq(parsed.source_symbols(), k)
      assert_eq(parsed.serialize(), original.serialize())
    }
  }
}

///|
test "OTI length reserved fields and unsupported profiles are rejected" {
  let oti = @moon-raptorq.Config::new(11, 4).unwrap().serialize()
  for length in 0..<12 {
    assert_true(@moon-raptorq.parse_config(oti[:length].to_owned()) is Err(_))
  }
  assert_true(@moon-raptorq.parse_config(b"1234567890123") is Err(_))
  assert_true(
    @moon-raptorq.parse_config(changed(oti, 5, 1))
    is Err(@moon-raptorq.InvalidParameters(_)),
  )
  for offset in [8, 9, 10, 11] {
    let wrong = changed(oti, offset, 2)
    assert_true(
      @moon-raptorq.parse_config(wrong)
      is Err(@moon-raptorq.UnsupportedProfile(_)),
    )
  }
  assert_true(
    @moon-raptorq.parse_config(changed(oti, 0, 1))
    is Err(@moon-raptorq.ResourceLimit(_)),
  )
  assert_true(
    @moon-raptorq.parse_config(changed(oti, 1, 128))
    is Err(@moon-raptorq.ResourceLimit(_)),
  )
}

///|
test "OTI cannot smuggle invalid T or zero object length" {
  for
    raw in [
      b"\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x01\x01", b"\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x01\x01",
      b"\x00\x00\x00\x00\x01\x00\xff\xff\x01\x00\x01\x01", b"\x00\x00\x00\x01\x01\x00\x00\x01\x01\x00\x01\x01",
    ] {
    assert_true(@moon-raptorq.parse_config(raw) is Err(_))
  }
}

///|
test "packet ESI byte order and all three byte carry boundaries" {
  let config = @moon-raptorq.Config::new(1, 1).unwrap()
  for
    (id, header) in [
      (0, b"\x00\x00\x00\x00"),
      (1, b"\x00\x00\x00\x01"),
      (255, b"\x00\x00\x00\xff"),
      (256, b"\x00\x00\x01\x00"),
      (65535, b"\x00\x00\xff\xff"),
      (65536, b"\x00\x01\x00\x00"),
      (16777215, b"\x00\xff\xff\xff"),
    ] {
    let packet = @moon-raptorq.Packet::new(id, b"\x81").unwrap()
    let bytes = packet.serialize()
    assert_eq(bytes[:4].to_owned(), header)
    assert_eq(bytes[4], 129)
    let parsed = config.parse_packet(bytes).unwrap()
    assert_eq(parsed.id(), id)
    assert_eq(parsed.payload(), b"\x81")
    assert_eq(parsed.serialize(), bytes)
  }
}

///|
test "packet constructor and parser enforce bounded exact framing" {
  for id in [-1, -2147483648, 16777216, 2147483647] {
    assert_true(@moon-raptorq.Packet::new(id, b"x") is Err(_))
  }
  assert_true(@moon-raptorq.Packet::new(0, b"") is Err(_))
  let large = @buffer.Buffer::Buffer()
  for _ in 0..<4097 {
    large.write_byte(0)
  }
  assert_true(@moon-raptorq.Packet::new(0, large.to_bytes()) is Err(_))
  let config = @moon-raptorq.Config::new(4, 4).unwrap()
  for raw in [b"", b"1234", b"1234567", b"123456789"] {
    assert_true(config.parse_packet(raw) is Err(@moon-raptorq.InvalidPacket(_)))
  }
  for block in [1, 2, 127, 255] {
    let raw = changed(b"\x001234567", 0, block.to_byte())
    assert_true(
      config.parse_packet(raw) is Err(@moon-raptorq.UnsupportedProfile(_)),
    )
  }
}

///|
test "parser accepts opaque payload contents without claiming authentication" {
  let config = @moon-raptorq.Config::new(4, 4).unwrap()
  for payload in [b"\x00\x00\x00\x00", b"\xff\x80\x00\x7f", b"test"] {
    let packet = @moon-raptorq.Packet::new(65537, payload).unwrap()
    assert_eq(
      config.parse_packet(packet.serialize()).unwrap().payload(),
      payload,
    )
  }
}

///|
test "many arbitrary OTI and packet inputs cannot bypass profile validation" {
  let mut state = 0x91827364U
  for _ in 0..<1024 {
    let out = @buffer.Buffer::Buffer()
    for _ in 0..<12 {
      state = state * 1664525U + 1013904223U
      out.write_byte((state >> 24).to_byte())
    }
    match @moon-raptorq.parse_config(out.to_bytes()) {
      Err(_) => ()
      Ok(config) => {
        assert_true(config.transfer_length() > 0)
        assert_true(config.source_symbols() <= 256)
        assert_true(config.symbol_size() <= 4096)
        assert_eq(config.serialize(), out.to_bytes())
      }
    }
  }
}
