///|
/// Polynomial convolution and long division, independent of the shift/XOR
/// multiplication used to construct the runtime table.
fn polynomial_product(a : Int32, b : Int32) -> Int32 {
  let mut polynomial = 0
  for bit in 0..<8 {
    if (b & (1 << bit)) != 0 {
      polynomial = polynomial ^ (a << bit)
    }
  }
  let mut degree = 14
  while degree >= 8 {
    if (polynomial & (1 << degree)) != 0 {
      polynomial = polynomial ^ (0x11d << (degree - 8))
    }
    degree -= 1
  }
  polynomial
}

///|
test "every GF256 product agrees with polynomial long division" {
  for a in 0..<256 {
    for b in 0..<256 {
      assert_eq(field_mul(a, b), polynomial_product(a, b))
    }
  }
}

///|
test "GF256 identities inverses and distributivity" {
  for a in 0..<256 {
    assert_eq(field_mul(a, 0), 0)
    assert_eq(field_mul(a, 1), a)
    assert_eq(field_power(a, 0), 1)
    assert_eq(field_power(a, 1), a)
    if a != 0 {
      assert_eq(field_mul(a, field_inverse(a)), 1)
      assert_eq(field_power(a, 255), 1)
    }
    for b in 0..<256 {
      let c = (b * 31 + 7) & 255
      assert_eq(field_mul(a, b), field_mul(b, a))
      assert_eq(field_mul(a, b ^ c), field_mul(a, b) ^ field_mul(a, c))
    }
  }
}

///|
test "alpha generates all nonzero field elements" {
  let seen = Array::make(256, false)
  let mut value = 1
  for _ in 0..<255 {
    assert_false(seen[value])
    seen[value] = true
    value = field_mul(value, 2)
  }
  assert_eq(value, 1)
  assert_false(seen[0])
  for i in 1..<256 {
    assert_true(seen[i])
  }
}

///|
test "scaled row operation respects prefix and special scalars" {
  let source = [3, 7, 9, 19]
  let target = [1, 2, 3, 4]
  add_scaled(target, source, 0, 0)
  assert_eq(target, [1, 2, 3, 4])
  add_scaled(target, source, 1, 2)
  assert_eq(target, [1, 2, 3 ^ 9, 4 ^ 19])
  add_scaled(target, source, 1, 2)
  assert_eq(target, [1, 2, 3, 4])
  add_scaled(target, source, 87, 4)
  assert_eq(target, [1, 2, 3, 4])
  add_scaled(target, source, 87, 0)
  for i in 0..<4 {
    assert_eq(target[i], (i + 1) ^ polynomial_product(source[i], 87))
  }
  assert_eq(source, [3, 7, 9, 19])
}

///|
test "matrix row storage does not alias" {
  let matrix = zero_matrix(3, 4)
  matrix[0][1] = 17
  assert_eq(matrix[1][1], 0)
  assert_eq(matrix[2][1], 0)
  assert_eq(matrix[0], [0, 17, 0, 0])
  assert_eq(zero_matrix(0, 3).length(), 0)
  assert_eq(zero_matrix(2, 0), [[], []])
}

///|
test "dense solver swaps and scales nonbinary pivots" {
  let a = [[0, 2, 1], [7, 3, 4], [0, 0, 9]]
  let expected = [[5, 6], [7, 8], [9, 10]]
  let rhs = zero_matrix(3, 2)
  for row in 0..<3 {
    for column in 0..<3 {
      add_scaled(rhs[row], expected[column], a[row][column], 0)
    }
  }
  assert_eq(solve(a, rhs, 3).unwrap(), Some(expected))
}

///|
test "dense solver detects rank deficiency and inconsistent equations" {
  assert_eq(solve([[1, 2], [2, 4]], [[8], [16]], 2).unwrap(), None)
  assert_true(
    solve([[1, 2], [2, 4]], [[8], [17]], 2) is Err(InconsistentEquations),
  )
  assert_eq(solve([[0, 1], [0, 0]], [[9], [0]], 2).unwrap(), None)
  assert_true(solve([[0, 1], [0, 0]], [[9], [1]], 2) is Err(_))
  assert_eq(solve([[0, 0]], [[0, 0]], 2).unwrap(), None)
}

///|
test "overdetermined consistent system and empty payload width" {
  let matrix = [[1, 0], [0, 1], [1, 1], [7, 3]]
  let rhs = [[6], [9], [6 ^ 9], [field_mul(7, 6) ^ field_mul(3, 9)]]
  assert_eq(solve(matrix, rhs, 2).unwrap(), Some([[6], [9]]))
  assert_eq(solve([[1]], [[]], 1).unwrap(), Some([[]]))
}

///|
test "online basis accepts out of order pivots" {
  let basis = Basis::new(3, 2)
  assert_eq(basis.solution(), None)
  assert_true(basis.insert([0, 0, 3], [27, 30]).unwrap())
  assert_true(basis.insert([1, 2, 0], [11, 22]).unwrap())
  assert_eq(basis.rank, 2)
  assert_true(basis.insert([0, 1, 0], [7, 8]).unwrap())
  let solution = basis.solution().unwrap()
  assert_eq(solution[2], [9, 10])
  assert_eq(solution[1], [7, 8])
  assert_eq(solution[0], [11 ^ field_mul(2, 7), 22 ^ field_mul(2, 8)])
  solution[0][0] = 99
  assert_eq(basis.solution().unwrap()[0][0], 11 ^ field_mul(2, 7))
}

///|
test "online dependent and conflicting equations leave basis unchanged" {
  let basis = Basis::new(2, 1)
  assert_true(basis.insert([1, 2], [3]).unwrap())
  assert_false(basis.insert([2, 4], [6]).unwrap())
  assert_eq(basis.rank, 1)
  assert_true(basis.insert([2, 4], [7]) is Err(InconsistentEquations))
  assert_eq(basis.rank, 1)
  assert_true(basis.insert([0, 1], [5]).unwrap())
  let result = basis.solution()
  assert_true(basis.insert([0, 0], [1]) is Err(_))
  assert_eq(basis.solution(), result)
  assert_false(basis.insert([0, 0], [0]).unwrap())
  assert_eq(basis.solution(), result)
}

///|
test "online and dense solvers agree on deterministic full rank systems" {
  for size in 1..<25 {
    let basis = Basis::new(size, 3)
    let matrix = zero_matrix(size + 4, size)
    let rhs = zero_matrix(size + 4, 3)
    let expected = zero_matrix(size, 3)
    for row in 0..<size {
      for byte in 0..<3 {
        expected[row][byte] = (row * 37 + byte * 83 + 11) & 255
      }
    }
    for row in 0..<(size + 4) {
      for column in 0..<size {
        // Unit lower triangle guarantees invertibility; surplus rows are dense.
        matrix[row][column] = if row < size {
          if column == row {
            1
          } else if column < row {
            (row * 7 + column * 19) & 255
          } else {
            0
          }
        } else {
          (row * 53 + column * 23 + 1) & 255
        }
        add_scaled(rhs[row], expected[column], matrix[row][column], 0)
      }
    }
    let mut row = matrix.length() - 1
    while row >= 0 {
      ignore(basis.insert(matrix[row].copy(), rhs[row].copy()).unwrap())
      row -= 1
    }
    assert_eq(basis.rank, size)
    assert_eq(basis.solution(), Some(expected))
    assert_eq(solve(matrix, rhs, size).unwrap(), Some(expected))
  }
}
