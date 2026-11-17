///|
test "optimized vector kernels agree with polynomial arithmetic for all scalars" {
  for scalar in 0..<256 {
    let source = Array::makei(256, i => i)
    let target = Array::makei(256, i => (i * 17 + 3) & 255)
    let scaled = source.copy()
    scale_row(scaled, scalar, 7)
    add_scaled(target, source, scalar, 7)
    for i in 0..<256 {
      assert_eq(
        scaled[i],
        if i < 7 {
          i
        } else {
          polynomial_product(i, scalar)
        },
      )
      assert_eq(
        target[i],
        ((i * 17 + 3) & 255) ^
        (if i < 7 { 0 } else { polynomial_product(i, scalar) }),
      )
    }
  }
}

///|
test "systematic shortcut is independent of order and preserves surplus conflict detection" {
  for k in [1, 2, 10, 64, 256] {
    let bytes = @buffer.Buffer::Buffer()
    for i in 0..<(k * 3 - 1) {
      bytes.write_byte((i & 255).to_byte())
    }
    let input = bytes.to_bytes()
    let encoder = Encoder::new(input, 3).unwrap()
    let decoder = Decoder::new(encoder.config())
    let mut id = k - 1
    while id >= 0 {
      ignore(decoder.push(encoder.packet(id).unwrap()).unwrap())
      id -= 1
    }
    assert_eq(decoder.decode().unwrap(), Some(input))
    assert_eq(decoder.decode().unwrap(), Some(input))
    let repair = encoder.packet(k).unwrap()
    let payload = repair.payload().to_array()
    payload[0] = payload[0] ^ 1
    ignore(
      decoder.push(Packet::new(k, Bytes::from_array(payload)).unwrap()).unwrap(),
    )
    assert_true(decoder.decode() is Err(InconsistentEquations))
  }
}
