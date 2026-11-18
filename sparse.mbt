///|
/// Sparse coefficient construction without allocating an L by L matrix.
fn sparse_constraints(p : Parameters) -> Array[Map[Int32, Int32]] {
  let rows = Array::makei(p.ldpc + p.hdpc, _ => Map([]))
  let width = p.lt - p.ldpc
  for column in 0..<width {
    let step = 1 + column / p.ldpc
    let mut row = column % p.ldpc
    for _ in 0..<3 {
      rows[row][column] = 1
      row = (row + step) % p.ldpc
    }
  }
  for row in 0..<p.ldpc {
    rows[row][row + width] = 1
    rows[row][row % p.pi + p.lt] = 1
    rows[row][(row + 1) % p.pi + p.lt] = 1
  }
  let last = p.extended + p.ldpc - 1
  let previous = Array::makei(p.hdpc, row => field_power(2, row))
  for row in 0..<p.hdpc {
    rows[p.ldpc + row][last] = previous[row]
    rows[p.ldpc + row][p.extended + p.ldpc + row] = 1
  }
  let mut column = last - 1
  while column >= 0 {
    let first = standard_random((column + 1).reinterpret_as_uint(), 6, p.hdpc)
    let second = (
        first +
        standard_random((column + 1).reinterpret_as_uint(), 7, p.hdpc - 1) +
        1
      ) %
      p.hdpc
    for row in 0..<p.hdpc {
      let value = field_mul(2, previous[row]) ^
        (if row == first || row == second { 1 } else { 0 })
      previous[row] = value
      if value != 0 {
        rows[p.ldpc + row][column] = value
      }
    }
    column -= 1
  }
  rows
}

///|
fn sparse_equation(p : Parameters, id : Int32) -> Map[Int32, Int32] {
  let row : Map[Int32, Int32] = Map([])
  for column in encoding_indices(p, id) {
    if row.get(column) is Some(_) {
      row.remove(column)
    } else {
      row[column] = 1
    }
  }
  row
}

///|
/// Inactivate all but one active column of a minimum-degree row. Elimination
/// introduces only inactive coefficients, so active-column incidence is static.
/// The residual dense system is explicitly capped before allocation.
fn sparse_solve(
  rows : Array[Map[Int32, Int32]],
  data : Array[Array[Int32]],
  columns : Int32,
  dense_entries : Int32,
  coefficient_limit~ : Int32 = 8388608,
) -> Result[Array[Array[Int32]]?, RaptorError] {
  let mut coefficient_count = 0
  for row in rows {
    coefficient_count += row.length()
  }
  if coefficient_count > coefficient_limit {
    return Err(ResourceLimit("sparse coefficient budget"))
  }
  let incidence = Array::makei(columns, _ => Array(capacity=0))
  let buckets = Array::makei(columns + 1, _ => Array(capacity=0))
  let degrees = Array::make(rows.length(), 0)
  let used = Array::make(rows.length(), false)
  let active = Array::make(columns, true)
  for i in 0..<rows.length() {
    degrees[i] = rows[i].length()
    buckets[degrees[i]].push(i)
    for column, _ in rows[i] {
      incidence[column].push(i)
    }
  }
  let inactive : Array[Int32] = []
  let pivots : Array[(Int32, Int32)] = []
  let mut remaining = columns
  let mut minimum = 1
  while remaining > 0 {
    let mut selected = -1
    while minimum <= columns && selected < 0 {
      while !buckets[minimum].is_empty() {
        let row = buckets[minimum].pop().unwrap()
        if !used[row] && degrees[row] == minimum {
          selected = row
          break
        }
      }
      if selected < 0 {
        minimum += 1
      }
    }
    if selected < 0 {
      return Ok(None)
    }
    let candidates : Array[Int32] = []
    for column, _ in rows[selected] {
      if active[column] {
        candidates.push(column)
      }
    }
    let pivot = candidates[0]
    for j in 1..<candidates.length() {
      let column = candidates[j]
      active[column] = false
      inactive.push(column)
      remaining -= 1
      for row in incidence[column] {
        if !used[row] {
          degrees[row] -= 1
          if degrees[row] > 0 {
            buckets[degrees[row]].push(row)
          }
        }
      }
    }
    used[selected] = true
    active[pivot] = false
    remaining -= 1
    let inverse = field_inverse(rows[selected].get(pivot).unwrap())
    let normalized : Map[Int32, Int32] = Map([])
    for column, value in rows[selected] {
      normalized[column] = field_mul(value, inverse)
    }
    rows[selected] = normalized
    scale_row(data[selected], inverse, 0)
    for row in incidence[pivot] {
      if used[row] {
        continue
      }
      let scalar = rows[row].get(pivot).unwrap()
      for column, value in normalized {
        let before = rows[row].get(column).unwrap_or(0)
        let combined = before ^ field_mul(scalar, value)
        if combined == 0 {
          if before != 0 {
            coefficient_count -= 1
          }
          rows[row].remove(column)
        } else {
          if before == 0 {
            coefficient_count += 1
          }
          rows[row][column] = combined
        }
      }
      if coefficient_count > coefficient_limit {
        return Err(ResourceLimit("sparse coefficient budget"))
      }
      add_scaled(data[row], data[selected], scalar, 0)
      degrees[row] -= 1
      if degrees[row] > 0 {
        buckets[degrees[row]].push(row)
      }
    }
    pivots.push((pivot, selected))
    minimum = 1
  }
  let residual_rows = rows.length() - pivots.length()
  if inactive.length() > 0 && residual_rows > dense_entries / inactive.length() {
    return Err(ResourceLimit("inactive dense coefficient budget"))
  }
  let matrix = zero_matrix(residual_rows, inactive.length())
  let rhs : Array[Array[Int32]] = []
  let mut target = 0
  for row in 0..<rows.length() {
    if !used[row] {
      for i in 0..<inactive.length() {
        matrix[target][i] = rows[row].get(inactive[i]).unwrap_or(0)
      }
      rhs.push(data[row])
      target += 1
    }
  }
  let values = match solve(matrix, rhs, inactive.length()) {
    Err(e) => return Err(e)
    Ok(None) => return Ok(None)
    Ok(Some(v)) => v
  }
  let width = data[0].length()
  let result = zero_matrix(columns, width)
  for i in 0..<inactive.length() {
    result[inactive[i]] = values[i]
  }
  for (column, row) in pivots {
    let value = data[row].copy()
    for other, coefficient in rows[row] {
      if other != column {
        add_scaled(value, result[other], coefficient, 0)
      }
    }
    result[column] = value
  }
  Ok(Some(result))
}
