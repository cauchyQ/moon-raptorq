///|
/// CRC32C detects accidental checkpoint corruption. It is not a MAC, signature
/// or object identity check, and cannot authenticate untrusted storage.
fn checkpoint_crc(bytes : Bytes) -> UInt32 {
  let table : Array[UInt32] = []
  for value in 0..<256 {
    let mut remainder = value.reinterpret_as_uint()
    for _ in 0..<8 {
      remainder = if (remainder & 1U) == 1U {
        (remainder >> 1) ^ 0x82f63b78U
      } else {
        remainder >> 1
      }
    }
    table.push(remainder)
  }
  let mut accumulator = 0xffffffffU
  for byte in bytes {
    let index = ((accumulator ^ byte.to_uint()) & 255U).reinterpret_as_int()
    accumulator = (accumulator >> 8) ^ table[index]
  }
  accumulator ^ 0xffffffffU
}

///|
/// Local checkpoint format v1: RQCP, version/reserved, u16 packet count,
/// standard OTI, concatenated standard packets, big-endian CRC32C.
/// This outer storage envelope is project-specific, not RFC 6330 wire format.
fn write_checkpoint(config : Config, packets : Array[Packet]) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  out.write_bytes(b"RQCP\x01\x00"[:])
  out.write_uint16_be(packets.length().to_uint16())
  out.write_bytes(config.serialize()[:])
  for packet in packets {
    out.write_bytes(packet.serialize()[:])
  }
  out.write_uint_be(checkpoint_crc(out.to_bytes()))
  out.to_bytes()
}

///|
fn read_checkpoint(
  bytes : Bytes,
) -> Result[(Config, Array[Packet]), RaptorError] {
  if bytes.length() < 24 {
    return Err(InvalidPacket("truncated checkpoint"))
  }
  if bytes.length() > 1312024 {
    return Err(ResourceLimit("checkpoint exceeds maximum supported size"))
  }
  if bytes[:4].to_owned() != b"RQCP" || bytes[4] != 1 || bytes[5] != 0 {
    return Err(InvalidPacket("unsupported checkpoint format"))
  }
  let config = match parse_config(bytes[8:20].to_owned()) {
    Err(error) => return Err(error)
    Ok(config) => config
  }
  let count = bytes.unsafe_read_uint16_be(6).to_int()
  if count > config.source_symbols + 64 {
    return Err(ResourceLimit("checkpoint packet budget exceeded"))
  }
  let size = config.symbol_size + 4
  let expected = 24 + count * size
  if bytes.length() != expected {
    return Err(InvalidPacket("checkpoint length does not match packet count"))
  }
  let content = bytes[:bytes.length() - 4].to_owned()
  if checkpoint_crc(content) != bytes.unsafe_read_uint32_be(bytes.length() - 4) {
    return Err(InvalidPacket("checkpoint CRC32C mismatch"))
  }
  let packets : Array[Packet] = []
  for index in 0..<count {
    let start = 20 + index * size
    let packet = match
      config.parse_packet(bytes[start:start + size].to_owned()) {
      Err(error) => return Err(error)
      Ok(packet) => packet
    }
    match validate_incoming(config, packets, packet) {
      Err(error) => return Err(error)
      Ok(false) =>
        return Err(InvalidPacket("checkpoint must not repeat an ESI"))
      Ok(true) => packets.push(packet)
    }
  }
  Ok((config, packets))
}

///|
/// Retain portable symbols instead of serializing backend-specific matrices.
pub fn Decoder::checkpoint(self : Decoder) -> Bytes {
  write_checkpoint(self.config, self.packets)
}

///|
pub fn StreamDecoder::checkpoint(self : StreamDecoder) -> Bytes {
  write_checkpoint(self.config, self.packets)
}

///|
/// Restoring a batch decoder validates framing and duplicates. Algebraic
/// consistency is checked at decode(), as with ordinary batch insertion.
pub fn restore_decoder(bytes : Bytes) -> Result[Decoder, RaptorError] {
  match read_checkpoint(bytes) {
    Err(error) => Err(error)
    Ok((config, packets)) => {
      let decoder = Decoder::new(config)
      for packet in packets {
        match decoder.push(packet) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      Ok(decoder)
    }
  }
}

///|
/// Restoring a streaming decoder replays each saved symbol once. A checksum
/// match does not exempt equations from the normal consistency checks.
pub fn restore_stream_decoder(
  bytes : Bytes,
) -> Result[StreamDecoder, RaptorError] {
  match read_checkpoint(bytes) {
    Err(error) => Err(error)
    Ok((config, packets)) => {
      let decoder = StreamDecoder::new(config)
      for packet in packets {
        match decoder.push(packet) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      Ok(decoder)
    }
  }
}
