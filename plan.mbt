///|
/// Reusable linear encoding transform for objects with the same source-symbol
/// count. Construction costs a dense solve; each object then needs only matrix
/// products. Useful for repeated fixed-size telemetry or asset blocks.
pub struct EncodingPlan {
  priv source_symbols : Int32
  priv coefficients : Array[Array[Int32]]
}

///|
pub fn EncodingPlan::new(
  source_symbols : Int32,
) -> Result[EncodingPlan, RaptorError] {
  if source_symbols < 1 || source_symbols > 256 {
    return Err(ResourceLimit("encoding plan requires 1..256 source symbols"))
  }
  let p = parameters(source_symbols)
  let matrix = precode(p)
  let rhs = zero_matrix(p.ldpc + p.hdpc, source_symbols)
  for id in 0..<p.extended {
    matrix.push(equation(p, id))
    let row = Array::make(source_symbols, 0)
    if id < source_symbols {
      row[id] = 1
    }
    rhs.push(row)
  }
  match solve(matrix, rhs, p.total) {
    Err(error) => Err(error)
    Ok(None) => Err(InconsistentEquations)
    Ok(Some(coefficients)) => Ok({ source_symbols, coefficients, })
  }
}

///|
pub fn EncodingPlan::source_symbols(self : EncodingPlan) -> Int32 {
  self.source_symbols
}

///|
/// Actual Int32 coefficient storage, excluding array headers and allocator
/// overhead. Plans can be shared across different symbol sizes and objects.
pub fn EncodingPlan::coefficient_bytes(self : EncodingPlan) -> Int32 {
  self.coefficients.length() * self.source_symbols * 4
}

///|
pub fn EncodingPlan::encode(
  self : EncodingPlan,
  data : Bytes,
  symbol_size : Int32,
) -> Result[Encoder, RaptorError] {
  let config = match Config::new(data.length(), symbol_size) {
    Err(error) => return Err(error)
    Ok(config) => config
  }
  if config.source_symbols != self.source_symbols {
    return Err(
      InvalidParameters("object source-symbol count differs from plan"),
    )
  }
  let source = zero_matrix(self.source_symbols, symbol_size)
  for id in 0..<self.source_symbols {
    for byte in 0..<symbol_size {
      let position = id * symbol_size + byte
      if position < data.length() {
        source[id][byte] = data[position].to_int()
      }
    }
  }
  let intermediate = zero_matrix(self.coefficients.length(), symbol_size)
  for row in 0..<self.coefficients.length() {
    for id in 0..<self.source_symbols {
      add_scaled(intermediate[row], source[id], self.coefficients[row][id], 0)
    }
  }
  Ok({ config, intermediate, })
}
