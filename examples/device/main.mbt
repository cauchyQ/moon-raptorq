///|
/// Configuration transfer with a contiguous outage, retransmissions and byte
/// chunks of irregular sizes. No real firmware update or signature is applied.
fn main raise {
  let scenario = @lab.scenarios()[1]
  let data = @lab.source(scenario.symbols * scenario.width - 1, 20261117U)
  let encoder = @rq.Encoder::new(data, scenario.width).unwrap()
  let decoder = @rq.StreamDecoder::new(encoder.config())
  let trace = @lab.trace(scenario, 20261117U, 0)
  let stream = @buffer.Buffer::Buffer()
  for sequence in trace {
    stream.write_bytes(encoder.packet(sequence).unwrap().serialize()[:])
  }
  let received = stream.to_bytes()
  let framer = @rq.PacketFramer::new(
    encoder.config(),
    max_packets=2 * scenario.budget,
  ).unwrap()
  let mut cursor = 0
  let mut chunks = 0
  let mut duplicates = 0
  while cursor < received.length() {
    let desired = 1 + chunks * 37 % 173
    let remaining = received.length() - cursor
    let length = if desired < remaining { desired } else { remaining }
    for
      packet in framer
      .push(received[cursor:cursor + length].to_owned())
      .unwrap() {
      if !decoder.push(packet).unwrap() {
        duplicates += 1
      }
    }
    cursor += length
    chunks += 1
  }
  assert_eq(framer.finish().unwrap(), trace.length())
  assert_true(duplicates > 0)
  assert_eq(decoder.decode().unwrap(), Some(data))
  println(
    "device: \{scenario.burst_length} consecutive packets lost, \{duplicates} duplicates ignored",
  )
  println("\{chunks} arbitrary byte chunks framed; exact recovery PASS")
  println("Authenticate real device payloads separately before applying them.")
}
