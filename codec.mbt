///|
/// Immutable encoder retaining intermediate symbols for on-demand repairs.
pub struct Encoder {
  priv config : Config
  priv intermediate : Array[Array[Int32]]
}

///|
/// Build the intermediate symbols using the RFC systematic constraints.
pub fn Encoder::new(
  data : Bytes,
  symbol_size : Int32,
) -> Result[Encoder, RaptorError] {
  let config = match Config::new(data.length(), symbol_size) {
    Ok(config) => config
    Err(error) => return Err(error)
  }
  let p = parameters(config.source_symbols)
  let matrix = precode(p)
  let rhs = zero_matrix(p.ldpc + p.hdpc, symbol_size)
  for id in 0..<p.extended {
    matrix.push(equation(p, id))
    let payload = Array::make(symbol_size, 0)
    for i in 0..<symbol_size {
      let index = id * symbol_size + i
      if index < data.length() {
        payload[i] = data[index].to_int()
      }
    }
    rhs.push(payload)
  }
  match solve(matrix, rhs, p.total) {
    Err(error) => Err(error)
    Ok(None) => Err(InconsistentEquations)
    Ok(Some(intermediate)) => Ok({ config, intermediate, })
  }
}

///|
pub fn Encoder::config(self : Encoder) -> Config {
  self.config
}

///|
/// ESI below K is systematic; ESI >=K generates repair symbols.
pub fn Encoder::packet(
  self : Encoder,
  id : Int32,
) -> Result[Packet, RaptorError] {
  if id < 0 || id >= 16777216 {
    return Err(InvalidPacket("ESI must fit 24 bits"))
  }
  let p = parameters(self.config.source_symbols)
  let internal_id = internal_id(self.config, p, id)
  Packet::new(
    id,
    encoded_payload(p, self.intermediate, internal_id, self.config.symbol_size),
  )
}

///|
/// Bounded receiver with duplicate checking and no hidden decode on insertion.
pub struct Decoder {
  priv config : Config
  priv packets : Array[Packet]
}

///|
pub fn Decoder::new(config : Config) -> Decoder {
  { config, packets: [], }
}

///|
/// True when a new symbol was retained; identical retransmissions return false.
pub fn Decoder::push(
  self : Decoder,
  packet : Packet,
) -> Result[Bool, RaptorError] {
  match validate_incoming(self.config, self.packets, packet) {
    Err(error) => return Err(error)
    Ok(false) => return Ok(false)
    Ok(true) => ()
  }
  self.packets.push(packet)
  Ok(true)
}

///|
pub fn Decoder::push_bytes(
  self : Decoder,
  bytes : Bytes,
) -> Result[Bool, RaptorError] {
  match self.config.parse_packet(bytes) {
    Ok(packet) => self.push(packet)
    Err(error) => Err(error)
  }
}

///|
pub fn Decoder::received(self : Decoder) -> Int32 {
  self.packets.length()
}

///|
/// None means insufficient independent equations, not a malformed packet.
pub fn Decoder::decode(self : Decoder) -> Result[Bytes?, RaptorError] {
  if self.packets.length() < self.config.source_symbols {
    return Ok(None)
  }
  let p = parameters(self.config.source_symbols)
  let matrix = precode(p)
  let rhs = zero_matrix(p.ldpc + p.hdpc, self.config.symbol_size)
  // Padding ESIs K..K'-1 have known zero source symbols.
  for id in self.config.source_symbols..<p.extended {
    matrix.push(equation(p, id))
    rhs.push(Array::make(self.config.symbol_size, 0))
  }
  for packet in self.packets {
    let internal_id = internal_id(self.config, p, packet.id)
    matrix.push(equation(p, internal_id))
    rhs.push(payload_row(packet.payload))
  }
  let intermediate = match solve(matrix, rhs, p.total) {
    Err(error) => return Err(error)
    Ok(None) => return Ok(None)
    Ok(Some(result)) => result
  }
  Ok(Some(recover_data(self.config, intermediate)))
}
