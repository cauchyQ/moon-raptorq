///|
test "all 477 RFC rows cover every legal K with minimal extension" {
  assert_eq(systematic_parameters.length(), 477)
  assert_eq(systematic_parameters[476].0, 56403)
  let mut entry = 0
  for k in 1..<56404 {
    while systematic_parameters[entry].0 < k {
      entry += 1
    }
    let p = parameters(k)
    assert_eq(p.extended, systematic_parameters[entry].0)
    assert_eq(p.systematic, systematic_parameters[entry].1)
    assert_true(p.extended >= k)
  }
}

///|
test "sparse constraints exactly match the independent dense construction" {
  for k in [1, 10, 18, 49, 128, 256, 511] {
    let p = parameters(k)
    let sparse = sparse_constraints(p)
    let dense = precode(p)
    assert_eq(sparse.length(), dense.length())
    for i in 0..<dense.length() {
      for j in 0..<p.total {
        assert_eq(sparse[i].get(j).unwrap_or(0), dense[i][j])
      }
    }
  }
}

///|
test "inactivation encoder matches dense output and recovers beyond the old cap" {
  for k in [1, 9, 18, 64, 256, 257, 511, 1024] {
    let symbols = Array::makei(k, i => {
      let out = @buffer.Buffer::Buffer()
      for j in 0..<3 {
        out.write_byte(((i * 17 + j * 11) % 256).to_byte())
      }
      out.to_bytes()
    })
    let encoder = StandardBlockEncoder::new(symbols).unwrap()
    if k <= 256 {
      let data = @buffer.Buffer::Buffer()
      for symbol in symbols {
        data.write_bytes(symbol[:])
      }
      let dense = Encoder::new(data.to_bytes(), 3).unwrap()
      for id in [0, k - 1, k, k + 11, 16777215] {
        assert_eq(
          encoder.symbol(id).unwrap(),
          dense.packet(id).unwrap().payload,
        )
      }
    }
    let decoder = StandardBlockDecoder::new(k, 3).unwrap()
    for id in 0..<k {
      assert_eq(encoder.symbol(id).unwrap(), symbols[id])
      if id % 3 != 0 {
        decoder.push(id, symbols[id]).unwrap() |> ignore
      }
    }
    for id in k..<(k + (k + 2) / 3 + 12) {
      decoder.push(id, encoder.symbol(id).unwrap()).unwrap() |> ignore
    }
    assert_eq(decoder.decode().unwrap(), Some(symbols))
  }
}

///|
test "inactivation solver retains rank and inconsistency semantics" {
  assert_true(
    sparse_solve([Map([(0, 1)]), Map([(0, 1)])], [[0], [1]], 1, 1024)
    is Err(InconsistentEquations),
  )
  assert_eq(sparse_solve([Map([(0, 1)])], [[1]], 2, 1024).unwrap(), None)
  let matrix = [Map([(0, 1), (1, 1)]), Map([(0, 1), (1, 2)])]
  assert_true(sparse_solve(matrix, [[1], [2]], 2, 0) is Err(ResourceLimit(_)))
}

///|
test "execution budgets and source-block routing reject before state changes" {
  assert_true(ExecutionLimits::new(symbol_elements=0L) is Err(_))
  let tiny = ExecutionLimits::new(symbol_elements=1L).unwrap()
  assert_true(
    StandardBlockEncoder::new([b"a"], limits=tiny) is Err(ResourceLimit(_)),
  )
  let tiny = ExecutionLimits::new(sparse_entries=1).unwrap()
  assert_true(
    StandardBlockEncoder::new([b"a"], limits=tiny) is Err(ResourceLimit(_)),
  )
  let info = TransmissionInfo::new(2L, 1, 2, 1, 1).unwrap()
  let decoder = StandardBlockDecoder::new(1, 1, source_block=1).unwrap()
  assert_true(
    decoder.push_packet(info.encoding_packet(0, 0, [b"a"]).unwrap()) is Err(_),
  )
  assert_true(decoder.decode().unwrap() is None)
  assert_eq(
    decoder.push_packet(info.encoding_packet(1, 0, [b"b"]).unwrap()).unwrap(),
    1,
  )
  assert_eq(decoder.decode().unwrap(), Some([b"b"]))
}

///|
test "maximum symbol width recovers byte-exact from repair symbols" {
  let out = @buffer.Buffer::Buffer()
  for i in 0..<65535 {
    out.write_byte(((i * 19 + 7) % 256).to_byte())
  }
  let source = out.to_bytes()
  let encoder = StandardBlockEncoder::new([source]).unwrap()
  let decoder = StandardBlockDecoder::new(1, 65535).unwrap()
  for id in 1..<9 {
    decoder.push(id, encoder.symbol(id).unwrap()).unwrap() |> ignore
  }
  assert_eq(decoder.decode().unwrap(), Some([source]))
}

///|
test "systematic large-block recovery bypasses solving but extra equations do not" {
  let limits = ExecutionLimits::new(sparse_entries=1, dense_entries=1).unwrap()
  let decoder = StandardBlockDecoder::new(56403, 1, limits~).unwrap()
  for id in 0..<56403 {
    decoder.push(id, b"a").unwrap() |> ignore
  }
  assert_true(decoder.decode().unwrap() is Some(_))
  decoder.push(56403, b"z").unwrap() |> ignore
  assert_true(decoder.decode() is Err(ResourceLimit(_)))
}
