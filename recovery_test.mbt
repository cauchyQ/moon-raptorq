///|
test "all supported K values preserve systematic symbols including padding" {
  for k in 1..<257 {
    let data = test_data(3 * k - 1, k.reinterpret_as_uint())
    let encoder = @moon-raptorq.Encoder::new(data, 3).unwrap()
    let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
    for id in 0..<k {
      let packet = encoder.packet(id).unwrap()
      for byte in 0..<3 {
        let position = 3 * id + byte
        let expected = if position < data.length() { data[position] } else { 0 }
        assert_eq(packet.payload()[byte], expected)
      }
      assert_true(receiver.push(packet).unwrap())
    }
    assert_true(receiver.progress().complete())
    assert_eq(receiver.decode().unwrap(), Some(data))
  }
}

///|
test "fixed seeded erasures reorder and duplicates preserve recovery" {
  for k in [1, 3, 9, 10, 11, 18, 32, 64, 128, 256] {
    let data = test_data(7 * k - 3, (k + 19).reinterpret_as_uint())
    let encoder = @moon-raptorq.Encoder::new(data, 7).unwrap()
    for loss in [0, 10, 30, 50] {
      let batch = @moon-raptorq.Decoder::new(encoder.config())
      let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
      let mut state = (k * 101 + loss + 1).reinterpret_as_uint()
      let mut retained = 0
      let mut id = 2 * k + 32
      while id >= 0 && retained < k + 8 {
        state = state * 1664525U + 1013904223U
        if (state % 100U).reinterpret_as_int() >= loss {
          let packet = encoder.packet(id).unwrap()
          assert_true(batch.push_bytes(packet.serialize()).unwrap())
          assert_true(stream.push_bytes(packet.serialize()).unwrap())
          assert_false(batch.push(packet).unwrap())
          assert_false(stream.push(packet).unwrap())
          retained += 1
        }
        id -= 1
      }
      assert_true(retained >= k)
      assert_eq(batch.decode().unwrap(), Some(data))
      assert_eq(stream.decode().unwrap(), Some(data))
    }
  }
}

///|
test "insufficient equations return waiting and more repairs can finish" {
  let data = test_data(127, 3U)
  let encoder = @moon-raptorq.Encoder::new(data, 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 32..<63 {
    let packet = encoder.packet(id).unwrap()
    ignore(batch.push(packet).unwrap())
    ignore(stream.push(packet).unwrap())
  }
  assert_eq(batch.decode().unwrap(), None)
  assert_eq(stream.decode().unwrap(), None)
  assert_false(stream.progress().complete())
  for id in 63..<76 {
    let packet = encoder.packet(id).unwrap()
    ignore(batch.push(packet).unwrap())
    ignore(stream.push(packet).unwrap())
  }
  assert_eq(batch.decode().unwrap(), Some(data))
  assert_eq(stream.decode().unwrap(), Some(data))
}

///|
test "zero and constant objects and one byte symbols recover via repairs" {
  for fill in [0, 1, 128, 255] {
    let out = @buffer.Buffer::Buffer()
    for _ in 0..<18 {
      out.write_byte(fill.to_byte())
    }
    let data = out.to_bytes()
    let encoder = @moon-raptorq.Encoder::new(data, 1).unwrap()
    let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
    for id in 18..<48 {
      ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
    }
    assert_eq(receiver.decode().unwrap(), Some(data))
  }
}

///|
test "maximum symbol width with partially filled final symbol" {
  let data = test_data(4097, 7U)
  let encoder = @moon-raptorq.Encoder::new(data, 4096).unwrap()
  let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 2..<14 {
    ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_eq(receiver.decode().unwrap(), Some(data))
}

///|
test "high repair ESIs wrap Tuple arithmetic without wrapping wire IDs" {
  let data = test_data(43, 999U)
  let encoder = @moon-raptorq.Encoder::new(data, 5).unwrap()
  let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
  for offset in 0..<25 {
    let id = 16777215 - offset
    let packet = encoder.packet(id).unwrap()
    assert_eq(packet.id(), id)
    ignore(receiver.push(packet).unwrap())
  }
  assert_eq(receiver.decode().unwrap(), Some(data))
  assert_true(encoder.packet(-1) is Err(_))
  assert_true(encoder.packet(16777216) is Err(_))
}
