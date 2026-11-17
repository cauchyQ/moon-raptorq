///|
/// One standard FEC payload ID followed by exactly one encoding symbol.
pub struct Packet {
  priv id : Int32
  priv payload : Bytes
}

///|
/// Source block number is zero in the supported single-block profile.
pub fn Packet::new(id : Int32, payload : Bytes) -> Result[Packet, RaptorError] {
  if id < 0 || id >= 16777216 {
    return Err(InvalidPacket("ESI must fit 24 bits"))
  }
  if payload.length() == 0 || payload.length() > 4096 {
    return Err(InvalidPacket("invalid payload size"))
  }
  Ok({ id, payload, })
}

///|
pub fn Packet::id(self : Packet) -> Int32 {
  self.id
}

///|
pub fn Packet::payload(self : Packet) -> Bytes {
  self.payload
}

///|
pub fn Packet::serialize(self : Packet) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  out.write_byte(0)
  out.write_byte((self.id >> 16).to_byte())
  out.write_byte(((self.id >> 8) & 255).to_byte())
  out.write_byte((self.id & 255).to_byte())
  out.write_bytes(self.payload[:])
  out.to_bytes()
}

///|
/// Strict one-symbol packet framing; aggregation is outside this API.
pub fn Config::parse_packet(
  self : Config,
  bytes : Bytes,
) -> Result[Packet, RaptorError] {
  if bytes.length() != self.symbol_size + 4 {
    return Err(InvalidPacket("packet length mismatch"))
  }
  if bytes[0] != 0 {
    return Err(UnsupportedProfile("source block must be zero"))
  }
  let id = bytes[1].to_int() * 65536 +
    bytes[2].to_int() * 256 +
    bytes[3].to_int()
  Packet::new(id, bytes[4:].to_owned())
}

///|
/// Standard 12-byte Object Transmission Information (Z=1, N=1, Al=1).
pub fn Config::serialize(self : Config) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  out.write_byte(0)
  out.write_uint_be(self.length.reinterpret_as_uint())
  out.write_byte(0)
  out.write_uint16_be(self.symbol_size.to_uint16())
  out.write_byte(1)
  out.write_uint16_be(1)
  out.write_byte(1)
  out.to_bytes()
}

///|
/// Parse only the explicitly supported single-source-block profile.
pub fn parse_config(bytes : Bytes) -> Result[Config, RaptorError] {
  if bytes.length() != 12 {
    return Err(InvalidParameters("OTI must contain 12 bytes"))
  }
  if bytes[5] != 0 {
    return Err(InvalidParameters("reserved byte must be zero"))
  }
  if bytes[0] != 0 {
    return Err(ResourceLimit("object length exceeds bounded profile"))
  }
  if bytes[8] != 1 || bytes[9] != 0 || bytes[10] != 1 || bytes[11] != 1 {
    return Err(UnsupportedProfile("requires Z=1, N=1, Al=1"))
  }
  let length = bytes.unsafe_read_uint32_be(1)
  if length > 1048576U {
    return Err(ResourceLimit("object length exceeds bounded profile"))
  }
  Config::new(
    length.reinterpret_as_int(),
    bytes.unsafe_read_uint16_be(6).to_int(),
  )
}
