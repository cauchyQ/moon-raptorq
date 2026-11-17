///|
/// Online row echelon form. A pivot owns its row and right-hand side.
struct Basis {
  columns : Int32
  width : Int32
  rows : Array[Array[Int32]?]
  data : Array[Array[Int32]?]
  mut rank : Int32
}

///|
fn Basis::new(columns : Int32, width : Int32) -> Basis {
  {
    columns,
    width,
    rows: Array::make(columns, None),
    data: Array::make(columns, None),
    rank: 0,
  }
}

///|
/// Only scratch inputs change on dependent or inconsistent input. The retained
/// basis changes only after a new pivot has been found and normalized.
fn Basis::insert(
  self : Basis,
  row : Array[Int32],
  data : Array[Int32],
) -> Result[Bool, RaptorError] {
  for column in 0..<self.columns {
    let scalar = row[column]
    if scalar == 0 {
      continue
    }
    match self.rows[column] {
      Some(pivot) => {
        add_scaled(row, pivot, scalar, column)
        add_scaled(data, self.data[column].unwrap(), scalar, 0)
      }
      None => {
        let inverse = field_inverse(scalar)
        scale_row(row, inverse, column)
        scale_row(data, inverse, 0)
        self.rows[column] = Some(row)
        self.data[column] = Some(data)
        self.rank += 1
        return Ok(true)
      }
    }
  }
  for value in data {
    if value != 0 {
      return Err(InconsistentEquations)
    }
  }
  Ok(false)
}

///|
/// Back substitution copies the retained RHS, so decoding is repeatable and
/// receiving additional equations after a decode remains well-defined.
fn Basis::solution(self : Basis) -> Array[Array[Int32]]? {
  if self.rank != self.columns {
    return None
  }
  let result = zero_matrix(self.columns, self.width)
  let mut column = self.columns - 1
  while column >= 0 {
    let row = self.rows[column].unwrap()
    let source = self.data[column].unwrap()
    for byte in 0..<self.width {
      result[column][byte] = source[byte]
    }
    for next in (column + 1)..<self.columns {
      add_scaled(result[column], result[next], row[next], 0)
    }
    column -= 1
  }
  Some(result)
}

///|
/// Progress counts independent source information, not just packet arrivals.
pub(all) struct Progress {
  received : Int32
  independent : Int32
  required : Int32
}

///|
pub fn Progress::complete(self : Progress) -> Bool {
  self.independent == self.required
}

///|
pub fn Progress::remaining(self : Progress) -> Int32 {
  self.required - self.independent
}

///|
/// Bounded incremental GF(256) receiver. Each packet is reduced once; repeated
/// decode calls do not rebuild or eliminate the full constraint matrix.
pub struct StreamDecoder {
  priv config : Config
  priv basis : Basis
  priv packets : Array[Packet]
}

///|
pub fn StreamDecoder::new(config : Config) -> StreamDecoder {
  let p = parameters(config.source_symbols)
  let basis = Basis::new(p.total, config.symbol_size)
  for row in precode(p) {
    ignore(basis.insert(row, Array::make(config.symbol_size, 0)).unwrap())
  }
  for id in config.source_symbols..<p.extended {
    ignore(
      basis.insert(equation(p, id), Array::make(config.symbol_size, 0)).unwrap(),
    )
  }
  { config, basis, packets: [], }
}

///|
pub fn StreamDecoder::config(self : StreamDecoder) -> Config {
  self.config
}

///|
/// A retained packet can be algebraically dependent and still be new. The
/// return value reports retention; use progress() for independent rank.
/// Inconsistent equations are rejected without retaining the packet.
pub fn StreamDecoder::push(
  self : StreamDecoder,
  packet : Packet,
) -> Result[Bool, RaptorError] {
  match validate_incoming(self.config, self.packets, packet) {
    Err(error) => return Err(error)
    Ok(false) => return Ok(false)
    Ok(true) => ()
  }
  let p = parameters(self.config.source_symbols)
  let id = internal_id(self.config, p, packet.id)
  match self.basis.insert(equation(p, id), payload_row(packet.payload)) {
    Err(error) => Err(error)
    Ok(_) => {
      self.packets.push(packet)
      Ok(true)
    }
  }
}

///|
pub fn StreamDecoder::push_bytes(
  self : StreamDecoder,
  bytes : Bytes,
) -> Result[Bool, RaptorError] {
  match self.config.parse_packet(bytes) {
    Err(error) => Err(error)
    Ok(packet) => self.push(packet)
  }
}

///|
pub fn StreamDecoder::progress(self : StreamDecoder) -> Progress {
  let p = parameters(self.config.source_symbols)
  {
    received: self.packets.length(),
    independent: self.basis.rank - (p.total - self.config.source_symbols),
    required: self.config.source_symbols,
  }
}

///|
pub fn StreamDecoder::decode(
  self : StreamDecoder,
) -> Result[Bytes?, RaptorError] {
  match self.basis.solution() {
    None => Ok(None)
    Some(intermediate) => Ok(Some(recover_data(self.config, intermediate)))
  }
}
