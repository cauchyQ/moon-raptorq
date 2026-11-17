///|
/// A standard source block number plus the same 24-bit ESI and symbol bytes
/// used by Packet. OTI is external, as specified by RFC 6330.
pub struct ObjectPacket {
  priv block : Int32
  priv symbol : Packet
}

///|
pub fn ObjectPacket::block(self : ObjectPacket) -> Int32 {
  self.block
}

///|
pub fn ObjectPacket::symbol(self : ObjectPacket) -> Packet {
  self.symbol
}

///|
pub fn ObjectPacket::serialize(self : ObjectPacket) -> Bytes {
  let bytes = self.symbol.serialize()
  let output = @buffer.Buffer::Buffer()
  output.write_byte(self.block.to_byte())
  output.write_bytes(bytes[1:])
  output.to_bytes()
}

///|
pub fn ObjectConfig::packet(
  self : ObjectConfig,
  block : Int32,
  symbol : Packet,
) -> Result[ObjectPacket, RaptorError] {
  if block < 0 || block >= self.blocks {
    return Err(InvalidPacket("source block number outside object"))
  }
  if symbol.payload.length() != self.symbol_size {
    return Err(InvalidPacket("symbol size mismatch"))
  }
  Ok({ block, symbol, })
}

///|
pub fn ObjectConfig::parse_packet(
  self : ObjectConfig,
  bytes : Bytes,
) -> Result[ObjectPacket, RaptorError] {
  if bytes.length() != self.symbol_size + 4 {
    return Err(InvalidPacket("packet length mismatch"))
  }
  let block = bytes[0].to_int()
  let id = bytes[1].to_int() * 65536 +
    bytes[2].to_int() * 256 +
    bytes[3].to_int()
  match Packet::new(id, bytes[4:].to_owned()) {
    Err(error) => Err(error)
    Ok(symbol) => self.packet(block, symbol)
  }
}
