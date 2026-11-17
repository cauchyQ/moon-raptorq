///|
fn main {
  let objects = [(53, 4, 3), (4101, 8, 3)]
  println("[")
  for position in 0..<objects.length() {
    let (length, size, blocks) = objects[position]
    let buffer = @buffer.Buffer::Buffer()
    for i in 0..<length {
      buffer.write_byte(((i * 17 + 11) % 256).to_byte())
    }
    let data = buffer.to_bytes()
    let encoder = @rq.ObjectEncoder::new(data, size, blocks).unwrap()
    println(
      "{\"size\":\{size},\"blocks\":\{blocks},\"data\":\"\{@hex.encode(data[:])}\",\"oti\":\"\{@hex.encode(encoder.config().serialize()[:])}\",\"packets\":[",
    )
    let packets : Array[Bytes] = []
    for block in 0..<blocks {
      let source = encoder.block(block).unwrap()
      let k = source.config().source_symbols()
      for id in 0..<(k + (k + 2) / 3 + 8) {
        if id >= k || id % 3 != 0 {
          packets.push(
            encoder
            .config()
            .packet(block, source.packet(id).unwrap())
            .unwrap()
            .serialize(),
          )
        }
      }
    }
    for i in 0..<packets.length() {
      let comma = if i + 1 == packets.length() { "" } else { "," }
      println("\"\{@hex.encode(packets[i][:])}\"\{comma}")
    }
    let comma = if position + 1 == objects.length() { "" } else { "," }
    println("]}\{comma}")
  }
  println("]")
}
