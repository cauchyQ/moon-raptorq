///|
test (b : @bench.T) {
  let data = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let encoder = Encoder::new(data, 4).unwrap()
  b.bench(name="encode_K16_T4", fn() { b.keep(Encoder::new(data, 4).unwrap()) })
  b.bench(name="repair_K16_T4", fn() { b.keep(encoder.packet(16).unwrap()) })
}

///|
test (b : @bench.T) {
  let data = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let plan = EncodingPlan::new(16).unwrap()
  b.bench(name="planned_encode_K16_T4", fn() {
    b.keep(plan.encode(data, 4).unwrap())
  })
  b.bench(name="build_plan_K16", fn() { b.keep(EncodingPlan::new(16).unwrap()) })
}

///|
test (b : @bench.T) {
  let data = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let encoder = Encoder::new(data, 4).unwrap()
  let packets : Array[Packet] = []
  for id in 16..<40 {
    packets.push(encoder.packet(id).unwrap())
  }
  b.bench(name="batch_repair_only_K16_T4", fn() {
    let decoder = Decoder::new(encoder.config())
    for packet in packets {
      ignore(decoder.push(packet).unwrap())
    }
    b.keep(decoder.decode().unwrap())
  })
  b.bench(name="stream_repair_only_K16_T4", fn() {
    let decoder = StreamDecoder::new(encoder.config())
    for packet in packets {
      ignore(decoder.push(packet).unwrap())
    }
    b.keep(decoder.decode().unwrap())
  })
}
