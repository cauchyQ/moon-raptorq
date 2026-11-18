///|
fn main {
  let results : Array[Json] = []
  for
    (f, t, z, n, al) in [
      (53, 12, 2, 3, 2),
      (101, 20, 3, 7, 4),
      (1025, 8, 4, 2, 1),
    ] {
    let info = @rq.TransmissionInfo::new(f.to_int64(), t, z, n, al).unwrap()
    let blocks : Array[Json] = []
    for block in 0..<z {
      let layout = info.block_layout(block).unwrap()
      let padded = @buffer.Buffer::Buffer()
      for i in 0..<layout.padded_length.to_int() {
        let at = layout.offset.to_int() + i
        padded.write_byte(
          if at < f {
            ((at * 17 + 11) % 256).to_byte()
          } else {
            0
          },
        )
      }
      let data = padded.to_bytes()
      let symbols = Array::makei(layout.symbols, id => {
        info.source_symbol(block, data, id).unwrap()
      })
      let encoder = @rq.StandardBlockEncoder::new(symbols).unwrap()
      let packets : Array[Json] = []
      for id in layout.symbols..<(2 * layout.symbols + 12) {
        // Rust reference is a single-block codec, so route each block as zero.
        let block_info = @rq.TransmissionInfo::new(
          layout.padded_length,
          t,
          1,
          1,
          1,
        ).unwrap()
        let packet = block_info
          .encoding_packet(0, id, [encoder.symbol(id).unwrap()])
          .unwrap()
        packets.push(@json.Json::string(@hex.encode(packet.serialize()[:])))
      }
      blocks.push(@json.Json::array(packets))
    }
    results.push(
      @json.Json::object({
        "f": @json.Json::number(f.to_double()),
        "t": @json.Json::number(t.to_double()),
        "z": @json.Json::number(z.to_double()),
        "n": @json.Json::number(n.to_double()),
        "al": @json.Json::number(al.to_double()),
        "blocks": @json.Json::array(blocks),
      }),
    )
  }
  println(@json.Json::array(results).stringify())
}
