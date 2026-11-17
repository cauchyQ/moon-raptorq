///|
/// More than 256 total symbols, transmitted one block at a time so the
/// receiver needs only one active elimination matrix.
fn main raise {
  let data = @lab.source(4101, 20261117U)
  let source = @rq.ObjectEncoder::new(data, 8, 3).unwrap()
  let config = @rq.parse_object_config(source.config().serialize()).unwrap()
  let receiver = @rq.ObjectDecoder::new(config, max_active_blocks=1).unwrap()
  for index in [2, 0, 1] {
    let block = source.block(index).unwrap()
    let k = block.config().source_symbols()
    // Use only repair symbols. Each completed block releases its matrix.
    for id in k..<(2 * k + 8) {
      let packet = config.packet(index, block.packet(id).unwrap()).unwrap()
      ignore(receiver.push_bytes(packet.serialize()).unwrap())
    }
    assert_eq(receiver.active_blocks(), 0)
    assert_true(receiver.block_progress(index).unwrap().complete())
    println(
      "source block \{index}: \{k} symbols, decoded and dense state released",
    )
  }
  assert_eq(receiver.completed_blocks(), 3)
  assert_eq(receiver.decode(), Some(data))
  println(
    "multi-block object: 4101 bytes, 513 source symbols, exact recovery PASS",
  )
}
