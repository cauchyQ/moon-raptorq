///|
test "supported parameter rows choose the smallest K prime" {
  let mut previous = 0
  for row in systematic_parameters {
    let (extended, systematic, s, h, w) = row
    assert_true(extended > previous)
    assert_true(is_prime(s))
    assert_true(is_prime(w))
    for k in (previous + 1)..<(extended + 1) {
      if k > 256 {
        break
      }
      let p = parameters(k)
      assert_eq(p.extended, extended)
      assert_eq(p.systematic, systematic)
      assert_eq(p.ldpc, s)
      assert_eq(p.hdpc, h)
      assert_eq(p.lt, w)
      assert_eq(p.total, extended + s + h)
      assert_eq(p.pi, p.total - w)
      assert_true(is_prime(p.prime))
      for n in p.pi..<p.prime {
        assert_false(is_prime(n))
      }
      assert_true(p.total > p.extended)
      assert_true(p.lt < p.total)
    }
    previous = extended
  }
  assert_true(previous >= 256)
}

///|
test "prime helper edge cases" {
  for value in [-1, 0, 1, 4, 6, 9, 15, 25, 49, 121] {
    assert_false(is_prime(value))
  }
  for value in [2, 3, 5, 7, 11, 17, 31, 257] {
    assert_true(is_prime(value))
  }
}

///|
test "Rand performs unsigned wrapping and produces bounded values" {
  for y in [0U, 1U, 255U, 256U, 65535U, 2147483648U, 4294967295U] {
    for index in 0..<8 {
      for modulus in [1, 2, 7, 29, 1048576] {
        let result = standard_random(y, index, modulus)
        assert_true(result >= 0 && result < modulus)
        let j = index.reinterpret_as_uint()
        let a = (y + j) % 256U
        let b = (y / 256U + j) % 256U
        let c = (y / 65536U + j) % 256U
        let d = (y / 16777216U + j) % 256U
        let expected = (
            random_v0[a.reinterpret_as_int()] ^
            random_v1[b.reinterpret_as_int()] ^
            random_v2[c.reinterpret_as_int()] ^
            random_v3[d.reinterpret_as_int()]
          ) %
          modulus.reinterpret_as_uint()
        assert_eq(result, expected.reinterpret_as_int())
      }
    }
  }
}

///|
test "tuple indices and equations remain in range including high ESIs" {
  for k in [1, 2, 9, 10, 11, 18, 32, 64, 128, 256] {
    let p = parameters(k)
    for
      id in [
        0,
        1,
        k - 1,
        k,
        p.extended,
        65535,
        16777215,
        16777215 + p.extended - k,
      ] {
      let indices = encoding_indices(p, id)
      let row = equation(p, id)
      assert_true(indices.length() >= 4)
      let counts = Array::make(p.total, 0)
      for index in indices {
        assert_true(index >= 0 && index < p.total)
        counts[index] += 1
      }
      for column in 0..<p.total {
        assert_eq(row[column], counts[column] % 2)
      }
    }
  }
}

///|
test "precode and known padding leave exactly K degrees of freedom" {
  for k in 1..<257 {
    let p = parameters(k)
    let basis = Basis::new(p.total, 1)
    let constraints = precode(p)
    assert_eq(constraints.length(), p.ldpc + p.hdpc)
    for row in constraints {
      assert_eq(row.length(), p.total)
      assert_true(basis.insert(row, [0]).unwrap())
    }
    for id in k..<p.extended {
      assert_true(basis.insert(equation(p, id), [0]).unwrap())
    }
    assert_eq(basis.rank, p.total - k)
    for id in 0..<k {
      assert_true(basis.insert(equation(p, id), [0]).unwrap())
    }
    assert_eq(basis.rank, p.total)
    assert_eq(basis.solution().unwrap(), zero_matrix(p.total, 1))
  }
}

///|
test "ESI to ISI inserts only the implicit zero padding interval" {
  for k in 1..<257 {
    let config = Config::new(k, 1).unwrap()
    let p = parameters(k)
    assert_eq(internal_id(config, p, 0), 0)
    assert_eq(internal_id(config, p, k - 1), k - 1)
    assert_eq(internal_id(config, p, k), p.extended)
    assert_eq(internal_id(config, p, k + 1), p.extended + 1)
    assert_eq(internal_id(config, p, 16777215), 16777215 + p.extended - k)
  }
}
