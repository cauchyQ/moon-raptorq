///|
/// Large-block execution path. Symbols are supplied in RFC interleaved order;
/// TransmissionInfo.source_symbol performs object-to-symbol layout conversion.
pub struct StandardBlockEncoder {
  priv k : Int32
  priv size : Int32
  priv intermediate : Array[Array[Int32]]
}

///|
fn validate_standard_symbols(
  k : Int32,
  size : Int32,
  limits : ExecutionLimits,
) -> Result[Unit, RaptorError] {
  if k < 1 || k > 56403 || size < 1 || size > 65535 {
    return Err(InvalidParameters("requires K=1..56403 and T=1..65535"))
  }
  // Resource policy, not a restriction on which RFC parameter values are valid.
  if parameters(k).total.to_int64() * size.to_int64() > limits.symbol_elements {
    return Err(
      ResourceLimit("intermediate symbol elements exceed execution budget"),
    )
  }
  Ok(())
}

///|
pub fn StandardBlockEncoder::new(
  symbols : Array[Bytes],
  limits~ : ExecutionLimits = ExecutionLimits::defaults(),
) -> Result[StandardBlockEncoder, RaptorError] {
  if symbols.is_empty() {
    return Err(InvalidParameters("source block is empty"))
  }
  let k = symbols.length()
  let size = symbols[0].length()
  match validate_standard_symbols(k, size, limits) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  for symbol in symbols {
    if symbol.length() != size {
      return Err(InvalidParameters("unequal source symbol lengths"))
    }
  }
  let p = parameters(k)
  let rows = sparse_constraints(p)
  let rhs = zero_matrix(p.ldpc + p.hdpc, size)
  for id in 0..<p.extended {
    rows.push(sparse_equation(p, id))
    rhs.push(
      if id < k {
        payload_row(symbols[id])
      } else {
        Array::make(size, 0)
      },
    )
  }
  match
    sparse_solve(
      rows,
      rhs,
      p.total,
      limits.dense_entries,
      coefficient_limit=limits.sparse_entries,
    ) {
    Err(e) => Err(e)
    Ok(None) => Err(InconsistentEquations)
    Ok(Some(intermediate)) => Ok({ k, size, intermediate, })
  }
}

///|
pub fn StandardBlockEncoder::symbol(
  self : StandardBlockEncoder,
  esi : Int32,
) -> Result[Bytes, RaptorError] {
  if esi < 0 || esi >= 16777216 {
    return Err(InvalidPacket("ESI must fit 24 bits"))
  }
  let p = parameters(self.k)
  let id = if esi < self.k { esi } else { esi + p.extended - self.k }
  Ok(encoded_payload(p, self.intermediate, id, self.size))
}

///|
pub struct StandardBlockDecoder {
  priv k : Int32
  priv size : Int32
  priv block : Int32
  priv limits : ExecutionLimits
  priv symbols : Map[Int32, Bytes]
}

///|
pub fn StandardBlockDecoder::new(
  k : Int32,
  symbol_size : Int32,
  source_block~ : Int32 = 0,
  limits~ : ExecutionLimits = ExecutionLimits::defaults(),
) -> Result[StandardBlockDecoder, RaptorError] {
  if source_block < 0 || source_block > 255 {
    return Err(InvalidParameters("invalid source block number"))
  }
  match validate_standard_symbols(k, symbol_size, limits) {
    Err(e) => Err(e)
    Ok(_) =>
      Ok({
        k,
        size: symbol_size,
        block: source_block,
        limits,
        symbols: Map([]),
      })
  }
}

///|
pub fn StandardBlockDecoder::push(
  self : StandardBlockDecoder,
  esi : Int32,
  payload : Bytes,
) -> Result[Bool, RaptorError] {
  if esi < 0 || esi >= 16777216 || payload.length() != self.size {
    return Err(InvalidPacket("invalid ESI or symbol size"))
  }
  match self.symbols.get(esi) {
    Some(previous) =>
      if previous == payload {
        return Ok(false)
      } else {
        return Err(ConflictingDuplicate(esi))
      }
    None => ()
  }
  if self.symbols.length() >= self.k + 4096 {
    return Err(ResourceLimit("retained symbol budget K+4096"))
  }
  self.symbols[esi] = payload
  Ok(true)
}

///|
/// Batch recovery preserves retained input on rank deficiency or budget error.
pub fn StandardBlockDecoder::decode(
  self : StandardBlockDecoder,
) -> Result[Array[Bytes]?, RaptorError] {
  if self.symbols.length() < self.k {
    return Ok(None)
  }
  // Exact systematic input needs no equation solving. Extra equations still
  // take the normal path so conflicting information is checked.
  if self.symbols.length() == self.k {
    let source : Array[Bytes] = []
    for id in 0..<self.k {
      match self.symbols.get(id) {
        Some(payload) => source.push(payload)
        None => break
      }
    }
    if source.length() == self.k {
      return Ok(Some(source))
    }
  }
  let p = parameters(self.k)
  let rows = sparse_constraints(p)
  let rhs = zero_matrix(p.ldpc + p.hdpc, self.size)
  for id in self.k..<p.extended {
    rows.push(sparse_equation(p, id))
    rhs.push(Array::make(self.size, 0))
  }
  for esi, payload in self.symbols {
    let id = if esi < self.k { esi } else { esi + p.extended - self.k }
    rows.push(sparse_equation(p, id))
    rhs.push(payload_row(payload))
  }
  match
    sparse_solve(
      rows,
      rhs,
      p.total,
      self.limits.dense_entries,
      coefficient_limit=self.limits.sparse_entries,
    ) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some(intermediate)) =>
      Ok(
        Some(
          Array::makei(self.k, id => {
            encoded_payload(p, intermediate, id, self.size)
          }),
        ),
      )
  }
}
