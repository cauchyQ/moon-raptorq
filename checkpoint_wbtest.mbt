///|
fn checkpoint_reseal(content : Bytes) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  output.write_bytes(content[:])
  output.write_uint_be(checkpoint_crc(content))
  output.to_bytes()
}

///|
fn checkpoint_replace(bytes : Bytes, index : Int32, value : Byte) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  for offset in 0..<bytes.length() {
    output.write_byte(if offset == index { value } else { bytes[offset] })
  }
  output.to_bytes()
}

///|
test "CRC32C known vector and independent bitwise recurrence" {
  assert_eq(checkpoint_crc(b"123456789"), 0xe3069283U)
  assert_eq(checkpoint_crc(b""), 0U)
  for length in 0..<257 {
    let bytes = @buffer.Buffer::Buffer()
    for index in 0..<length {
      bytes.write_byte(((index * 71 + 3) & 255).to_byte())
    }
    let input = bytes.to_bytes()
    let mut reference = 0xffffffffU
    for byte in input {
      reference = reference ^ byte.to_uint()
      for _ in 0..<8 {
        let low = reference & 1U
        reference = reference >> 1
        if low == 1U {
          reference = reference ^ 0x82f63b78U
        }
      }
    }
    assert_eq(checkpoint_crc(input), reference ^ 0xffffffffU)
  }
}

///|
test "valid checksum cannot bypass checkpoint version reserved and profile guards" {
  let config = Config::new(8, 4).unwrap()
  let bytes = Decoder::new(config).checkpoint()
  let content = bytes[:20].to_owned()
  for
    (index, value) in [
      (0, 0),
      (4, 0),
      (4, 2),
      (5, 1),
      (16, 2),
      (18, 2),
      (19, 2),
    ] {
    let corrupted = checkpoint_replace(content, index, value.to_byte())
    assert_true(read_checkpoint(checkpoint_reseal(corrupted)) is Err(_))
  }
  for count in [1, 66, 67, 255] {
    let wrong = checkpoint_replace(content, 7, count.to_byte())
    assert_true(read_checkpoint(checkpoint_reseal(wrong)) is Err(_))
  }
}

///|
test "checkpoint rejects identical and conflicting duplicate ESIs with valid CRC" {
  let encoder = Encoder::new(b"abcdefgh", 4).unwrap()
  let first = encoder.packet(0).unwrap()
  for second in [first, Packet::new(0, b"xxxx").unwrap()] {
    let bytes = write_checkpoint(encoder.config(), [first, second])
    assert_true(read_checkpoint(bytes) is Err(_))
    assert_true(restore_decoder(bytes) is Err(_))
    assert_true(restore_stream_decoder(bytes) is Err(_))
  }
}

///|
test "checkpoint rejects foreign blocks with valid CRC" {
  let encoder = Encoder::new(b"abcdefgh", 4).unwrap()
  let bytes = write_checkpoint(encoder.config(), [encoder.packet(0).unwrap()])
  let content = bytes[:bytes.length() - 4].to_owned()
  let foreign = checkpoint_reseal(checkpoint_replace(content, 20, 1))
  assert_true(read_checkpoint(foreign) is Err(UnsupportedProfile(_)))
}

///|
test "algebraically inconsistent but checksum valid checkpoints fail at the documented stage" {
  let encoder = Encoder::new(b"abcdefgh", 4).unwrap()
  let repair = encoder.packet(2).unwrap()
  let payload = checkpoint_replace(repair.payload(), 0, repair.payload()[0] ^ 1)
  let bytes = write_checkpoint(encoder.config(), [
    encoder.packet(0).unwrap(),
    encoder.packet(1).unwrap(),
    Packet::new(2, payload).unwrap(),
  ])
  assert_true(restore_stream_decoder(bytes) is Err(InconsistentEquations))
  let batch = restore_decoder(bytes).unwrap()
  assert_true(batch.decode() is Err(InconsistentEquations))
}

///|
test "checkpoint parser rejects oversized buffers and count overflow before replay" {
  let oversized = Bytes::from_array(Array::make(1312025, 0))
  assert_true(read_checkpoint(oversized) is Err(ResourceLimit(_)))
  let config = Config::new(256, 1).unwrap()
  let saved = Decoder::new(config).checkpoint()
  let content = saved[:20].to_owned()
  let high_count = checkpoint_replace(
    checkpoint_replace(content, 6, 255),
    7,
    255,
  )
  assert_true(
    read_checkpoint(checkpoint_reseal(high_count)) is Err(ResourceLimit(_)),
  )
  let declared_maximum = checkpoint_replace(
    checkpoint_replace(content, 6, 1),
    7,
    64,
  )
  assert_true(
    read_checkpoint(checkpoint_reseal(declared_maximum))
    is Err(InvalidPacket(_)),
  )
}
