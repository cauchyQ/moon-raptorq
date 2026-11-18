///|
test "complete OTI field widths round trip without allocating an object" {
  for
    (f, t, z, n, a) in [
      (0L, 1, 1, 1, 1),
      (942574504275L, 65535, 255, 65535, 255),
      (4294967297L, 4096, 32, 3, 4),
      (53L, 12, 2, 2, 4),
    ] {
    let info = @moon-raptorq.TransmissionInfo::new(f, t, z, n, a).unwrap()
    let copy = @moon-raptorq.parse_transmission_info(info.serialize()).unwrap()
    assert_eq(copy.transfer_length(), f)
    assert_eq(copy.symbol_size(), t)
    assert_eq(copy.source_blocks(), z)
    assert_eq(copy.sub_blocks(), n)
    assert_eq(copy.alignment(), a)
  }
  assert_true(
    @moon-raptorq.TransmissionInfo::new(942574504276L, 65535, 255, 1, 1)
    is Err(_),
  )
  assert_true(@moon-raptorq.TransmissionInfo::new(56404L, 1, 1, 1, 1) is Err(_))
  assert_true(@moon-raptorq.TransmissionInfo::new(4L, 3, 1, 1, 2) is Err(_))
  assert_true(@moon-raptorq.block_parameters(56403) is Ok(_))
  assert_true(@moon-raptorq.block_parameters(56404) is Err(_))
}

///|
test "subblock gather implements the normative interleaving and inverse" {
  let info = @moon-raptorq.TransmissionInfo::new(11L, 6, 1, 2, 1).unwrap()
  let source = b"abcdefghijkl"
  assert_eq(info.source_symbol(0, source, 0).unwrap(), b"abcghi")
  assert_eq(info.source_symbol(0, source, 1).unwrap(), b"defjkl")
  assert_eq(
    info.reassemble_block(0, [b"abcghi", b"defjkl"]).unwrap(),
    b"abcdefghijk",
  )
}

///|
test "aligned uneven subblocks conserve byte offsets over multiple blocks" {
  for size in [4, 8, 12, 20] {
    for n in [1, 2, 3, 7] {
      let info = @moon-raptorq.TransmissionInfo::new(101L, size, 3, n, 4).unwrap()
      let mut end = 0L
      for block in 0..<3 {
        let layout = info.block_layout(block).unwrap()
        assert_eq(layout.offset, end)
        let source = @buffer.Buffer::Buffer()
        for i in 0..<layout.padded_length.to_int() {
          source.write_byte((i % 256).to_byte())
        }
        let source = source.to_bytes()
        let symbols = Array::makei(layout.symbols, id => {
          info.source_symbol(block, source, id).unwrap()
        })
        assert_eq(
          info.reassemble_block(block, symbols).unwrap(),
          source[:layout.data_length.to_int()].to_owned(),
        )
        let mut sub_end = layout.offset
        for sub in 0..<n {
          let part = info.subblock_layout(block, sub).unwrap()
          assert_eq(part.offset, sub_end)
          assert_eq(part.subsymbol_size % 4, 0)
          sub_end += part.length
        }
        assert_eq(sub_end, layout.offset + layout.padded_length)
        end += layout.padded_length
      }
      assert_true(end >= 101L && end < 101L + size.to_int64())
    }
  }
}
