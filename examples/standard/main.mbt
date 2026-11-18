///|
fn main raise {
  let source = b"Sub-block interleaving and aggregated repair packets in pure MoonBit."
  let info = @rq.TransmissionInfo::new(source.length().to_int64(), 12, 2, 3, 2).unwrap()
  let output = @buffer.Buffer::Buffer()
  for block in 0..<info.source_blocks() {
    let layout = info.block_layout(block).unwrap()
    let padded = @buffer.Buffer::Buffer()
    for i in 0..<layout.padded_length.to_int() {
      let at = layout.offset.to_int() + i
      padded.write_byte(if at < source.length() { source[at] } else { 0 })
    }
    let data = padded.to_bytes()
    let symbols = Array::makei(layout.symbols, id => {
      info.source_symbol(block, data, id).unwrap()
    })
    let encoder = @rq.StandardBlockEncoder::new(symbols).unwrap()
    let decoder = @rq.StandardBlockDecoder::new(
      layout.symbols,
      12,
      source_block=block,
    ).unwrap()
    // Repair-only delivery, aggregated under one FEC Payload ID.
    let repairs = Array::makei(layout.symbols + 12, i => {
      encoder.symbol(layout.symbols + i).unwrap()
    })
    let packet = info.encoding_packet(block, layout.symbols, repairs).unwrap()
    decoder
    .push_packet(info.parse_encoding_packet(packet.serialize()).unwrap())
    .unwrap()
    |> ignore
    let recovered = decoder.decode().unwrap().unwrap()
    output.write_bytes(info.reassemble_block(block, recovered).unwrap()[:])
  }
  assert_eq(output.to_bytes(), source)
  println(
    "PASS: aligned sub-blocks, multiple source blocks, aggregated repair-only recovery",
  )
}
