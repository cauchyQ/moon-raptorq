///|
fn internal_id(config : Config, p : Parameters, id : Int32) -> Int32 {
  if id < config.source_symbols {
    id
  } else {
    id + p.extended - config.source_symbols
  }
}

///|
fn payload_row(payload : Bytes) -> Array[Int32] {
  let result : Array[Int32] = []
  for byte in payload {
    result.push(byte.to_int())
  }
  result
}

///|
fn recover_data(config : Config, intermediate : Array[Array[Int32]]) -> Bytes {
  let p = parameters(config.source_symbols)
  let output = @buffer.Buffer::Buffer()
  for id in 0..<config.source_symbols {
    let payload = encoded_payload(p, intermediate, id, config.symbol_size)
    let remaining = config.length - id * config.symbol_size
    let count = if remaining < config.symbol_size {
      remaining
    } else {
      config.symbol_size
    }
    output.write_bytes(payload[:count])
  }
  output.to_bytes()
}

///|
fn validate_incoming(
  config : Config,
  previous : Array[Packet],
  packet : Packet,
) -> Result[Bool, RaptorError] {
  if packet.payload.length() != config.symbol_size {
    return Err(InvalidPacket("symbol size mismatch"))
  }
  for existing in previous {
    if existing.id == packet.id {
      if existing.payload != packet.payload {
        return Err(ConflictingDuplicate(packet.id))
      }
      return Ok(false)
    }
  }
  if previous.length() >= config.source_symbols + 64 {
    return Err(ResourceLimit("receiver limit K+64 packets"))
  }
  Ok(true)
}
