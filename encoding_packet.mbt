///|
/// RFC 6330 packet: one payload ID followed by consecutive encoding symbols.
pub struct EncodingPacket {
  priv block : Int32
  priv first : Int32
  priv symbols : Array[Bytes]
}

///|
pub fn EncodingPacket::source_block(self : EncodingPacket) -> Int32 {
  self.block
}

///|
pub fn EncodingPacket::first_esi(self : EncodingPacket) -> Int32 {
  self.first
}

///|
pub fn EncodingPacket::symbols(self : EncodingPacket) -> Array[Bytes] {
  self.symbols.copy()
}

///|
pub fn TransmissionInfo::encoding_packet(
  self : TransmissionInfo,
  block : Int32,
  first : Int32,
  symbols : Array[Bytes],
) -> Result[EncodingPacket, RaptorError] {
  match self.validate_encoding_range(block, first, symbols.length()) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  for symbol in symbols {
    if symbol.length() != self.size {
      return Err(InvalidPacket("symbol size differs from OTI"))
    }
  }
  Ok({ block, first, symbols: symbols.copy(), })
}

///|
fn TransmissionInfo::validate_encoding_range(
  self : TransmissionInfo,
  block : Int32,
  first : Int32,
  count : Int32,
) -> Result[Unit, RaptorError] {
  let layout = match self.block_layout(block) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if first < 0 || first >= 16777216 || count < 1 || count > 16777216 - first {
    return Err(InvalidPacket("invalid consecutive encoding symbol range"))
  }
  if first < layout.symbols && count > layout.symbols - first {
    return Err(InvalidPacket("source and repair symbols cannot share a packet"))
  }
  if count.to_int64() * self.size.to_int64() > 2147483643L {
    return Err(ResourceLimit("aggregate packet exceeds host byte indexing"))
  }
  Ok(())
}

///|
pub fn EncodingPacket::serialize(self : EncodingPacket) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  out.write_byte(self.block.to_byte())
  for shift in [16, 8, 0] {
    out.write_byte(((self.first >> shift) & 255).to_byte())
  }
  for symbol in self.symbols {
    out.write_bytes(symbol[:])
  }
  out.to_bytes()
}

///|
pub fn TransmissionInfo::parse_encoding_packet(
  self : TransmissionInfo,
  bytes : Bytes,
) -> Result[EncodingPacket, RaptorError] {
  if bytes.length() < 4 || (bytes.length() - 4) % self.size != 0 {
    return Err(InvalidPacket("payload must contain complete encoding symbols"))
  }
  let count = (bytes.length() - 4) / self.size
  let first = bytes[1].to_int() * 65536 +
    bytes[2].to_int() * 256 +
    bytes[3].to_int()
  let block = bytes[0].to_int()
  // Reject invalid routing/ranges before allocating one object per symbol.
  match self.validate_encoding_range(block, first, count) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let symbols = Array::makei(count, i => {
    bytes[4 + i * self.size:4 + (i + 1) * self.size].to_owned()
  })
  Ok({ block, first, symbols, })
}

///|
/// Validate the whole datagram before retaining any of its symbols.
pub fn StandardBlockDecoder::push_packet(
  self : StandardBlockDecoder,
  packet : EncodingPacket,
) -> Result[Int32, RaptorError] {
  if packet.block != self.block {
    return Err(InvalidPacket("packet belongs to another source block"))
  }
  let mut added = 0
  for i in 0..<packet.symbols.length() {
    let id = packet.first + i
    let payload = packet.symbols[i]
    if payload.length() != self.size {
      return Err(InvalidPacket("symbol size mismatch"))
    }
    match self.symbols.get(id) {
      Some(previous) =>
        if previous != payload {
          return Err(ConflictingDuplicate(id))
        }
      None => added += 1
    }
  }
  if self.symbols.length() + added > self.k + 4096 {
    return Err(ResourceLimit("retained symbol budget K+4096"))
  }
  for i in 0..<packet.symbols.length() {
    self.symbols[packet.first + i] = packet.symbols[i]
  }
  Ok(added)
}
