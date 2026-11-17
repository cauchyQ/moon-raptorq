///|
/// Run the same deterministic handoff on WebAssembly or JavaScript. Network
/// arrival order is reversed and includes duplicates; the wire bytes are the
/// same format tested against the independent Rust implementation.
fn main raise {
  let scenario = @lab.scenarios()[2]
  let length = scenario.symbols * scenario.width - 1
  let plan = @rq.EncodingPlan::new(scenario.symbols).unwrap()
  for object in 0..<3 {
    let data = @lab.source(length, (20261117 + object).reinterpret_as_uint())
    let encoder = plan.encode(data, scenario.width).unwrap()
    let config = @rq.parse_config(encoder.config().serialize()).unwrap()
    let receiver = @rq.StreamDecoder::new(config)
    let trace = @lab.trace(scenario, 20261117U, 0)
    let mut duplicates = 0
    for sequence in trace {
      let packet = encoder.packet(sequence).unwrap().serialize()
      if !receiver.push_bytes(packet).unwrap() {
        duplicates += 1
      }
    }
    assert_true(duplicates > 0)
    assert_eq(receiver.decode().unwrap(), Some(data))
    println(
      "object \{object}: reversed arrivals, \{duplicates} duplicates, exact recovery",
    )
  }
  let estimate = @rq.Config::new(length, scenario.width)
    .unwrap()
    .stream_storage()
  println(
    "plan coefficients: \{plan.coefficient_bytes()} raw bytes, reused for three objects",
  )
  println(
    "stream raw storage bound: \{estimate.raw_total()} bytes, excluding runtime overhead",
  )
  println("edge handoff PASS")
}
