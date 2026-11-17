///|
/// Framing for the single-source-block API. Chunk errors are atomic; finish
/// rejects a truncated frame and seals the reader after success.
pub struct PacketFramer {
  priv config : Config
  priv buffer : FrameBuffer
}

///|
pub fn PacketFramer::new(
  config : Config,
  max_packets~ : Int32 = 4096,
) -> Result[PacketFramer, RaptorError] {
  FrameBuffer::new(config.symbol_size + 4, max_packets~).map(buffer => {
    config,
    buffer,
  })
}

///|
pub fn PacketFramer::buffered(self : PacketFramer) -> Int32 {
  self.buffer.buffered()
}

///|
pub fn PacketFramer::parsed(self : PacketFramer) -> Int32 {
  self.buffer.parsed()
}

///|
pub fn PacketFramer::push(
  self : PacketFramer,
  chunk : Bytes,
) -> Result[Array[Packet], RaptorError] {
  self.buffer.push(chunk, bytes => self.config.parse_packet(bytes))
}

///|
pub fn PacketFramer::finish(self : PacketFramer) -> Result[Int32, RaptorError] {
  self.buffer.finish()
}

///|
/// Identical byte-stream framing with source block demultiplexing. Each frame
/// must use a valid source block number from the object's OTI.
pub struct ObjectFramer {
  priv config : ObjectConfig
  priv buffer : FrameBuffer
}

///|
pub fn ObjectFramer::new(
  config : ObjectConfig,
  max_packets~ : Int32 = 4096,
) -> Result[ObjectFramer, RaptorError] {
  FrameBuffer::new(config.symbol_size + 4, max_packets~).map(buffer => {
    config,
    buffer,
  })
}

///|
pub fn ObjectFramer::buffered(self : ObjectFramer) -> Int32 {
  self.buffer.buffered()
}

///|
pub fn ObjectFramer::parsed(self : ObjectFramer) -> Int32 {
  self.buffer.parsed()
}

///|
pub fn ObjectFramer::push(
  self : ObjectFramer,
  chunk : Bytes,
) -> Result[Array[ObjectPacket], RaptorError] {
  self.buffer.push(chunk, bytes => self.config.parse_packet(bytes))
}

///|
pub fn ObjectFramer::finish(self : ObjectFramer) -> Result[Int32, RaptorError] {
  self.buffer.finish()
}
