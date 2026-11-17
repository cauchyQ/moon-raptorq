///|
test "stream rank tracks independent information across all source symbols" {
  let data = b"An incremental decoder accumulates independent equations."
  let encoder = @moon-raptorq.Encoder::new(data, 4).unwrap()
  let decoder = @moon-raptorq.StreamDecoder::new(encoder.config())
  let k = encoder.config().source_symbols()
  assert_eq(decoder.config().serialize(), encoder.config().serialize())
  assert_eq(decoder.progress().received, 0)
  assert_eq(decoder.progress().independent, 0)
  assert_eq(decoder.progress().remaining(), k)
  assert_false(decoder.progress().complete())
  for id in 0..<k {
    assert_true(decoder.push(encoder.packet(id).unwrap()).unwrap())
    let progress = decoder.progress()
    assert_eq(progress.received, id + 1)
    assert_eq(progress.independent, id + 1)
    assert_eq(progress.required, k)
    assert_eq(progress.remaining(), k - id - 1)
    if id < k - 1 {
      assert_eq(decoder.decode().unwrap(), None)
    }
  }
  assert_true(decoder.progress().complete())
  assert_eq(decoder.decode().unwrap(), Some(data))
  assert_eq(decoder.decode().unwrap(), Some(data))
}

///|
test "both receivers reject conflicting duplicates without state changes" {
  let encoder = @moon-raptorq.Encoder::new(b"12345678", 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  let packet = encoder.packet(0).unwrap()
  assert_true(batch.push(packet).unwrap())
  assert_true(stream.push(packet).unwrap())
  assert_false(batch.push_bytes(packet.serialize()).unwrap())
  assert_false(stream.push_bytes(packet.serialize()).unwrap())
  let invalid = @moon-raptorq.Packet::new(0, b"0000").unwrap()
  assert_true(batch.push(invalid) is Err(@moon-raptorq.ConflictingDuplicate(0)))
  assert_true(
    stream.push(invalid) is Err(@moon-raptorq.ConflictingDuplicate(0)),
  )
  assert_eq(batch.received(), 1)
  assert_eq(stream.progress().received, 1)
  assert_eq(stream.progress().independent, 1)
  assert_true(batch.push(encoder.packet(1).unwrap()).unwrap())
  assert_true(stream.push(encoder.packet(1).unwrap()).unwrap())
  assert_eq(batch.decode().unwrap(), Some(b"12345678"))
  assert_eq(stream.decode().unwrap(), Some(b"12345678"))
}

///|
test "malformed packets and symbol size mismatch never consume receiver budget" {
  let config = @moon-raptorq.Config::new(8, 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(config)
  let stream = @moon-raptorq.StreamDecoder::new(config)
  for payload in [b"x", b"123", b"12345"] {
    let packet = @moon-raptorq.Packet::new(1, payload).unwrap()
    assert_true(batch.push(packet) is Err(@moon-raptorq.InvalidPacket(_)))
    assert_true(stream.push(packet) is Err(@moon-raptorq.InvalidPacket(_)))
  }
  for raw in [b"", b"1234", b"12345678"] {
    assert_true(batch.push_bytes(raw) is Err(_))
    assert_true(stream.push_bytes(raw) is Err(_))
  }
  assert_eq(batch.received(), 0)
  assert_eq(stream.progress().received, 0)
  assert_eq(stream.progress().independent, 0)
}

///|
test "receiver retention bound is exact and retransmission works at capacity" {
  let encoder = @moon-raptorq.Encoder::new(b"abcd", 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 0..<65 {
    let packet = encoder.packet(id).unwrap()
    assert_true(batch.push(packet).unwrap())
    assert_true(stream.push(packet).unwrap())
  }
  assert_eq(batch.received(), 65)
  assert_eq(stream.progress().received, 65)
  assert_eq(stream.progress().independent, 1)
  assert_true(
    batch.push(encoder.packet(65).unwrap())
    is Err(@moon-raptorq.ResourceLimit(_)),
  )
  assert_true(
    stream.push(encoder.packet(65).unwrap())
    is Err(@moon-raptorq.ResourceLimit(_)),
  )
  assert_false(batch.push(encoder.packet(0).unwrap()).unwrap())
  assert_false(stream.push(encoder.packet(0).unwrap()).unwrap())
  assert_eq(batch.decode().unwrap(), Some(b"abcd"))
  assert_eq(stream.decode().unwrap(), Some(b"abcd"))
}

///|
test "inconsistent extra equation is rejected by online reduction" {
  let data = b"abcdefgh"
  let encoder = @moon-raptorq.Encoder::new(data, 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 0..<2 {
    let packet = encoder.packet(id).unwrap()
    ignore(batch.push(packet).unwrap())
    ignore(stream.push(packet).unwrap())
  }
  let good = encoder.packet(2).unwrap()
  let bad = @moon-raptorq.Packet::new(
    2,
    changed(good.payload(), 0, good.payload()[0] ^ 1),
  ).unwrap()
  assert_true(stream.push(bad) is Err(@moon-raptorq.InconsistentEquations))
  assert_eq(stream.progress().received, 2)
  assert_eq(stream.decode().unwrap(), Some(data))
  ignore(batch.push(bad).unwrap())
  assert_true(batch.decode() is Err(@moon-raptorq.InconsistentEquations))
  assert_true(stream.push(good).unwrap())
  assert_eq(stream.decode().unwrap(), Some(data))
}

///|
test "repair only stream decodes and tolerates further consistent equations" {
  let data = b"No systematic packets arrive in this transfer."
  let encoder = @moon-raptorq.Encoder::new(data, 3).unwrap()
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  let k = encoder.config().source_symbols()
  for id in k..<(2 * k + 12) {
    assert_true(
      stream.push_bytes(encoder.packet(id).unwrap().serialize()).unwrap(),
    )
  }
  assert_true(stream.progress().complete())
  assert_eq(stream.decode().unwrap(), Some(data))
  let before = stream.progress().received
  assert_true(stream.push(encoder.packet(16777215).unwrap()).unwrap())
  assert_eq(stream.progress().received, before + 1)
  assert_eq(stream.progress().remaining(), 0)
  assert_eq(stream.decode().unwrap(), Some(data))
}

///|
test "same ID sequences in separate decoder instances do not share state" {
  let a = @moon-raptorq.Encoder::new(b"first--", 2).unwrap()
  let b = @moon-raptorq.Encoder::new(b"second!", 2).unwrap()
  let da = @moon-raptorq.StreamDecoder::new(a.config())
  let db = @moon-raptorq.StreamDecoder::new(b.config())
  for id in 0..<4 {
    ignore(da.push(a.packet(id).unwrap()).unwrap())
    assert_eq(db.progress().received, id)
    ignore(db.push(b.packet(id).unwrap()).unwrap())
  }
  assert_eq(da.decode().unwrap(), Some(b"first--"))
  assert_eq(db.decode().unwrap(), Some(b"second!"))
}
