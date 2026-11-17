///|
/// One immutable encoder serves six independently lossy receivers. No
/// receiver-specific missing-packet list is used to produce repairs.
fn main raise {
  let scenario = @lab.scenarios()[0]
  let data = @lab.source(scenario.symbols * scenario.width - 1, 20261117U)
  let source = @rq.Encoder::new(data, scenario.width).unwrap()
  let receivers : Array[@rq.StreamDecoder] = []
  let traces : Array[Array[Int32]] = []
  for index in 0..<scenario.receivers {
    receivers.push(
      @rq.StreamDecoder::new(
        @rq.parse_config(source.config().serialize()).unwrap(),
      ),
    )
    traces.push(@lab.trace(scenario, 20261117U, index))
  }
  for sequence in 0..<scenario.budget {
    let bytes = source.packet(sequence).unwrap().serialize()
    for index in 0..<receivers.length() {
      for arriving in traces[index] {
        if arriving == sequence {
          ignore(receivers[index].push_bytes(bytes).unwrap())
        }
      }
    }
  }
  for index in 0..<receivers.length() {
    let receiver = receivers[index]
    assert_eq(receiver.decode().unwrap(), Some(data))
    println(
      "receiver \{index}: \{receiver.progress().received} packets, exact recovery",
    )
  }
  println("multicast: one encoder, six independent loss traces, PASS")
}
