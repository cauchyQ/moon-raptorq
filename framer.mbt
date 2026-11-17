///|
/// Incremental parser for concatenated single-symbol RFC packets with the
/// same OTI. Symbol size fixes the frame length; no extra wire bytes are added.
struct FrameBuffer {
  size : Int32
  limit : Int32
  partial : Array[Byte]
  mut used : Int32
  mut packets : Int32
  mut finished : Bool
}

///|
fn FrameBuffer::new(
  size : Int32,
  max_packets~ : Int32 = 4096,
) -> Result[FrameBuffer, RaptorError] {
  if max_packets < 1 || max_packets > 65536 {
    return Err(ResourceLimit("framer packet budget must be 1..65536"))
  }
  Ok({
    size,
    limit: max_packets,
    partial: Array::make(size, 0),
    used: 0,
    packets: 0,
    finished: false,
  })
}

///|
fn FrameBuffer::buffered(self : FrameBuffer) -> Int32 {
  self.used
}

///|
fn FrameBuffer::parsed(self : FrameBuffer) -> Int32 {
  self.packets
}

///|
/// Chunk processing is atomic. Errors do not consume partial input or lose
/// valid packets preceding an invalid frame in the same chunk.
fn[T] FrameBuffer::push(
  self : FrameBuffer,
  chunk : Bytes,
  parse : (Bytes) -> Result[T, RaptorError],
) -> Result[Array[T], RaptorError] {
  if self.finished {
    return Err(InvalidPacket("framer is already finished"))
  }
  let size = self.size
  let capacity = (self.limit - self.packets) * size - self.used
  if chunk.length() > capacity {
    return Err(ResourceLimit("framer packet budget exhausted"))
  }
  let partial = self.partial.copy()
  let mut used = self.used
  let result : Array[T] = []
  for byte in chunk {
    partial[used] = byte
    used += 1
    if used == size {
      match parse(Bytes::from_array(partial)) {
        Err(error) => return Err(error)
        Ok(packet) => result.push(packet)
      }
      used = 0
    }
  }
  for index in 0..<used {
    self.partial[index] = partial[index]
  }
  self.used = used
  self.packets += result.length()
  Ok(result)
}

///|
/// A truncated stream can be extended after this error. Successful finish
/// seals the parser; all subsequent push calls, including empty ones, fail.
fn FrameBuffer::finish(self : FrameBuffer) -> Result[Int32, RaptorError] {
  if self.used != 0 {
    return Err(InvalidPacket("truncated final packet"))
  }
  self.finished = true
  Ok(self.packets)
}
