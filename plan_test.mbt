///|
fn test_data(length : Int32, seed : UInt32) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  let mut state = seed
  for _ in 0..<length {
    state = state * 1664525U + 1013904223U
    output.write_byte((state >> 24).to_byte())
  }
  output.to_bytes()
}

///|
test "reusable encoding plans match direct solve across sizes and padded tails" {
  for k in [1, 2, 3, 9, 10, 11, 18, 32, 64] {
    let plan = @moon-raptorq.EncodingPlan::new(k).unwrap()
    assert_eq(plan.source_symbols(), k)
    assert_true(plan.coefficient_bytes() >= k * k * 4)
    for size in [1, 3, 17] {
      let data = test_data((k - 1) * size + 1, (k * size).reinterpret_as_uint())
      let direct = @moon-raptorq.Encoder::new(data, size).unwrap()
      let planned = plan.encode(data, size).unwrap()
      assert_eq(planned.config().serialize(), direct.config().serialize())
      for id in [0, k - 1, k, k + 1, k + 12, 16777215] {
        assert_eq(
          planned.packet(id).unwrap().serialize(),
          direct.packet(id).unwrap().serialize(),
        )
      }
    }
  }
}

///|
test "encoding plan is immutable across interleaved objects" {
  let plan = @moon-raptorq.EncodingPlan::new(16).unwrap()
  let first = test_data(64, 1U)
  let second = test_data(63, 2U)
  let a = plan.encode(first, 4).unwrap()
  let original = a.packet(30).unwrap().serialize()
  let b = plan.encode(second, 4).unwrap()
  assert_eq(a.packet(30).unwrap().serialize(), original)
  let da = @moon-raptorq.StreamDecoder::new(a.config())
  let db = @moon-raptorq.StreamDecoder::new(b.config())
  for id in 16..<44 {
    ignore(da.push(a.packet(id).unwrap()).unwrap())
    ignore(db.push(b.packet(id).unwrap()).unwrap())
  }
  assert_eq(da.decode().unwrap(), Some(first))
  assert_eq(db.decode().unwrap(), Some(second))
  assert_eq(
    plan.encode(first, 4).unwrap().packet(30).unwrap().serialize(),
    original,
  )
}

///|
test "encoding plan rejects invalid counts and mismatched objects" {
  for k in [-1, 0, 257, 2147483647] {
    assert_true(@moon-raptorq.EncodingPlan::new(k) is Err(_))
  }
  let plan = @moon-raptorq.EncodingPlan::new(4).unwrap()
  for data in [b"", b"x", b"01234567890123456"] {
    assert_true(plan.encode(data, 4) is Err(_))
  }
  assert_true(plan.encode(b"0123456789012345", 0) is Err(_))
  assert_true(plan.encode(b"0123456789012345", 4097) is Err(_))
  assert_true(plan.encode(b"0123456789012345", 4) is Ok(_))
}
