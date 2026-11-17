///|
test "checkpoint resumes incomplete recovery through either decoder implementation" {
  let data = test_data(127, 19U)
  let encoder = @moon-raptorq.Encoder::new(data, 4).unwrap()
  let initial = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 32..<48 {
    ignore(initial.push(encoder.packet(id).unwrap()).unwrap())
  }
  let bytes = initial.checkpoint()
  let batch = @moon-raptorq.restore_decoder(bytes).unwrap()
  let stream = @moon-raptorq.restore_stream_decoder(bytes).unwrap()
  assert_eq(batch.received(), 16)
  assert_eq(stream.progress().received, 16)
  assert_eq(stream.progress().independent, initial.progress().independent)
  assert_eq(batch.decode().unwrap(), None)
  assert_eq(stream.decode().unwrap(), None)
  assert_eq(batch.checkpoint(), bytes)
  assert_eq(stream.checkpoint(), bytes)
  for id in 48..<80 {
    let packet = encoder.packet(id).unwrap()
    ignore(batch.push(packet).unwrap())
    ignore(stream.push(packet).unwrap())
  }
  assert_eq(batch.decode().unwrap(), Some(data))
  assert_eq(stream.decode().unwrap(), Some(data))
  assert_eq(batch.checkpoint(), stream.checkpoint())
  assert_eq(initial.progress().received, 16)
  assert_eq(initial.decode().unwrap(), None)
}

///|
test "empty and completed receiver checkpoints are stable" {
  let encoder = @moon-raptorq.Encoder::new(b"abcdefgh", 4).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  let initial = batch.checkpoint()
  assert_eq(initial.length(), 24)
  assert_eq(@moon-raptorq.restore_decoder(initial).unwrap().received(), 0)
  assert_eq(
    @moon-raptorq.restore_stream_decoder(initial).unwrap().progress().independent,
    0,
  )
  for id in [1, 0, 10, 20] {
    ignore(batch.push(encoder.packet(id).unwrap()).unwrap())
  }
  let saved = batch.checkpoint()
  let restored = @moon-raptorq.restore_stream_decoder(saved).unwrap()
  assert_eq(restored.decode().unwrap(), Some(b"abcdefgh"))
  assert_eq(restored.checkpoint(), saved)
  assert_false(restored.push(encoder.packet(1).unwrap()).unwrap())
  assert_eq(restored.checkpoint(), saved)
}

///|
test "every single byte corruption of a real checkpoint is rejected" {
  let encoder = @moon-raptorq.Encoder::new(b"checkpoint checksum boundaries", 4).unwrap()
  let stream = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 0..<5 {
    ignore(stream.push(encoder.packet(id).unwrap()).unwrap())
  }
  let saved = stream.checkpoint()
  for index in 0..<saved.length() {
    let damaged = changed(saved, index, saved[index] ^ 1)
    assert_true(@moon-raptorq.restore_decoder(damaged) is Err(_))
    assert_true(@moon-raptorq.restore_stream_decoder(damaged) is Err(_))
  }
  for length in 0..<saved.length() {
    assert_true(
      @moon-raptorq.restore_decoder(saved[:length].to_owned()) is Err(_),
    )
  }
  let trailing = @buffer.Buffer::Buffer()
  trailing.write_bytes(saved[:])
  trailing.write_byte(0)
  assert_true(@moon-raptorq.restore_decoder(trailing.to_bytes()) is Err(_))
  assert_eq(stream.checkpoint(), saved)
}

///|
test "checkpoint retention limit and maximal payload width roundtrip" {
  let encoder = @moon-raptorq.Encoder::new(b"x", 4096).unwrap()
  let batch = @moon-raptorq.Decoder::new(encoder.config())
  for id in 0..<65 {
    ignore(batch.push(encoder.packet(id).unwrap()).unwrap())
  }
  let bytes = batch.checkpoint()
  assert_eq(bytes.length(), 24 + 65 * 4100)
  let receiver = @moon-raptorq.restore_stream_decoder(bytes).unwrap()
  assert_eq(receiver.progress().received, 65)
  assert_eq(receiver.decode().unwrap(), Some(b"x"))
  assert_true(
    receiver.push(encoder.packet(65).unwrap())
    is Err(@moon-raptorq.ResourceLimit(_)),
  )
}

///|
test "restarting after every packet preserves progress and duplicate checks" {
  let data = test_data(53, 41U)
  let encoder = @moon-raptorq.Encoder::new(data, 3).unwrap()
  let mut decoder = @moon-raptorq.StreamDecoder::new(encoder.config())
  for id in 0..<18 {
    ignore(decoder.push(encoder.packet(id).unwrap()).unwrap())
    let rank = decoder.progress().independent
    let bytes = decoder.checkpoint()
    let restored_batch = @moon-raptorq.restore_decoder(bytes).unwrap()
    decoder = @moon-raptorq.restore_stream_decoder(restored_batch.checkpoint()).unwrap()
    assert_eq(decoder.progress().independent, rank)
    assert_eq(decoder.progress().received, id + 1)
    assert_false(decoder.push(encoder.packet(id).unwrap()).unwrap())
    assert_eq(decoder.checkpoint(), bytes)
  }
  assert_eq(decoder.decode().unwrap(), Some(data))
}

///|
test "checkpoint canonical header preserves arrival order and high repair ESI" {
  let encoder = @moon-raptorq.Encoder::new(b"abcdefghi", 4).unwrap()
  let decoder = @moon-raptorq.Decoder::new(encoder.config())
  let high = encoder.packet(16777215).unwrap()
  let low = encoder.packet(0).unwrap()
  ignore(decoder.push(high).unwrap())
  ignore(decoder.push(low).unwrap())
  let saved = decoder.checkpoint()
  assert_eq(saved.length(), 40)
  assert_eq(saved[:8].to_owned(), b"RQCP\x01\x00\x00\x02")
  assert_eq(saved[8:20].to_owned(), encoder.config().serialize())
  assert_eq(saved[20:28].to_owned(), high.serialize())
  assert_eq(saved[28:36].to_owned(), low.serialize())
  let restored = @moon-raptorq.restore_stream_decoder(saved).unwrap()
  assert_eq(restored.config().transfer_length(), 9)
  assert_eq(restored.progress().received, 2)
  assert_false(restored.push(high).unwrap())
  for id in 1..<3 {
    ignore(restored.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_eq(restored.decode().unwrap(), Some(b"abcdefghi"))
  assert_eq(decoder.received(), 2)
}
