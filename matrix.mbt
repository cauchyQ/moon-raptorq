///|
/// Allocate independent rows: Array::make(rows, row) would alias mutable data.
fn zero_matrix(rows : Int32, columns : Int32) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for _ in 0..<rows {
    result.push(Array::make(columns, 0))
  }
  result
}

///|
/// LDPC and HDPC constraints from RFC 6330 sections 5.3.3.3--5.3.3.4.
/// HDPC recurrence adapted from cberner/raptorq constraint_matrix.rs, Apache-2.0.
fn precode(p : Parameters) -> Array[Array[Int32]] {
  let matrix = zero_matrix(p.ldpc + p.hdpc, p.total)
  let width = p.lt - p.ldpc
  for column in 0..<width {
    let step = 1 + column / p.ldpc
    let mut row = column % p.ldpc
    for _ in 0..<3 {
      matrix[row][column] = 1
      row = (row + step) % p.ldpc
    }
  }
  for row in 0..<p.ldpc {
    matrix[row][row + width] = 1
    matrix[row][row % p.pi + p.lt] = 1
    matrix[row][(row + 1) % p.pi + p.lt] = 1
  }
  let last = p.extended + p.ldpc - 1
  for row in 0..<p.hdpc {
    matrix[p.ldpc + row][last] = field_power(2, row)
    matrix[p.ldpc + row][p.extended + p.ldpc + row] = 1
  }
  let mut column = last - 1
  while column >= 0 {
    for row in 0..<p.hdpc {
      matrix[p.ldpc + row][column] = field_mul(
        2,
        matrix[p.ldpc + row][column + 1],
      )
    }
    let first = standard_random((column + 1).reinterpret_as_uint(), 6, p.hdpc)
    let second = (
        first +
        standard_random((column + 1).reinterpret_as_uint(), 7, p.hdpc - 1) +
        1
      ) %
      p.hdpc
    matrix[p.ldpc + first][column] = matrix[p.ldpc + first][column] ^ 1
    matrix[p.ldpc + second][column] = matrix[p.ldpc + second][column] ^ 1
    column -= 1
  }
  matrix
}

///|
fn equation(p : Parameters, id : Int32) -> Array[Int32] {
  let row = Array::make(p.total, 0)
  for index in encoding_indices(p, id) {
    row[index] = row[index] ^ 1
  }
  row
}

///|
/// Solve A*C=D without exposing partial state. Inputs are scratch matrices.
/// ponytail: dense bounded solver first; sparse inactivation is future work.
fn solve(
  matrix : Array[Array[Int32]],
  data : Array[Array[Int32]],
  columns : Int32,
) -> Result[Array[Array[Int32]]?, RaptorError] {
  let mut rank = 0
  let pivots : Array[Int32] = []
  for column in 0..<columns {
    let mut pivot = rank
    while pivot < matrix.length() && matrix[pivot][column] == 0 {
      pivot += 1
    }
    if pivot == matrix.length() {
      continue
    }
    let old_row = matrix[rank]
    matrix[rank] = matrix[pivot]
    matrix[pivot] = old_row
    let old_data = data[rank]
    data[rank] = data[pivot]
    data[pivot] = old_data
    let inverse = field_inverse(matrix[rank][column])
    for i in column..<columns {
      matrix[rank][i] = field_mul(matrix[rank][i], inverse)
    }
    for i in 0..<data[rank].length() {
      data[rank][i] = field_mul(data[rank][i], inverse)
    }
    for row in (rank + 1)..<matrix.length() {
      let scalar = matrix[row][column]
      if scalar != 0 {
        add_scaled(matrix[row], matrix[rank], scalar, column)
        add_scaled(data[row], data[rank], scalar, 0)
      }
    }
    pivots.push(column)
    rank += 1
  }
  for row in rank..<matrix.length() {
    for value in data[row] {
      if value != 0 {
        return Err(InconsistentEquations)
      }
    }
  }
  if rank < columns {
    return Ok(None)
  }
  let mut row = rank - 1
  while row >= 0 {
    for previous in 0..<row {
      let scalar = matrix[previous][pivots[row]]
      if scalar != 0 {
        add_scaled(data[previous], data[row], scalar, 0)
        matrix[previous][pivots[row]] = 0
      }
    }
    row -= 1
  }
  let result : Array[Array[Int32]] = []
  for i in 0..<columns {
    result.push(data[i])
  }
  Ok(Some(result))
}

///|
fn encoded_payload(
  p : Parameters,
  intermediate : Array[Array[Int32]],
  id : Int32,
  symbol_size : Int32,
) -> Bytes {
  let payload = Array::make(symbol_size, 0)
  for index in encoding_indices(p, id) {
    add_scaled(payload, intermediate[index], 1, 0)
  }
  let out = @buffer.Buffer::Buffer()
  for value in payload {
    out.write_byte(value.to_byte())
  }
  out.to_bytes()
}
