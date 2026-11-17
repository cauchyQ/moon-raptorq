///|
test "raw storage estimates are positive monotone and bounded across profiles" {
  let mut previous = 0
  for k in 1..<257 {
    let config = @moon-raptorq.Config::new(k * 128, 128).unwrap()
    let storage = config.stream_storage()
    assert_true(storage.raw_total() >= previous)
    assert_eq(storage.retained_payload_bytes, (k + 64) * 128)
    assert_eq(storage.shared_field_table_bytes, 262144)
    assert_true(storage.coefficient_bytes >= k * k * 4)
    assert_true(storage.symbol_bytes >= k * 128 * 4)
    assert_true(storage.decode_scratch_bytes >= k * 128 * 4 + k * 128)
    assert_eq(
      storage.raw_total(),
      storage.coefficient_bytes +
      storage.symbol_bytes +
      storage.retained_payload_bytes +
      storage.decode_scratch_bytes +
      storage.shared_field_table_bytes,
    )
    previous = storage.raw_total()
  }
  let small = @moon-raptorq.Config::new(256, 1).unwrap().stream_storage()
  let large = @moon-raptorq.Config::new(1048576, 4096).unwrap().stream_storage()
  assert_eq(small.coefficient_bytes, large.coefficient_bytes)
  assert_eq(small.shared_field_table_bytes, large.shared_field_table_bytes)
  assert_true(large.raw_total() > small.raw_total())
  assert_true(large.raw_total() < 20000000)
}

///|
test "combined maximum profile recovers a full one MiB object" {
  let source = test_data(1048576, 20261117U)
  let encoder = @moon-raptorq.Encoder::new(source, 4096).unwrap()
  let receiver = @moon-raptorq.StreamDecoder::new(encoder.config())
  // Some systematic symbols are missing; repairs must recover the actual
  // maximum object, rather than merely accepting its Config constructor.
  for id in 0..<256 {
    if id % 17 != 0 {
      ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
    }
  }
  for id in 256..<280 {
    ignore(receiver.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_true(receiver.progress().complete())
  assert_eq(receiver.decode().unwrap(), Some(source))
}
