///|
/// Simulate a receiver restart using only persisted bytes. Matrices and
/// in-memory decoder instances are not carried across the restart boundary.
fn main raise {
  let data = @lab.source(1023, 20261117U)
  let encoder = @rq.Encoder::new(data, 32).unwrap()
  let before = @rq.StreamDecoder::new(encoder.config())
  for id in 32..<48 {
    ignore(before.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_eq(before.decode().unwrap(), None)
  let saved = before.checkpoint()
  let after = @rq.restore_stream_decoder(saved).unwrap()
  assert_eq(after.progress().received, 16)
  assert_eq(after.progress().independent, before.progress().independent)
  // A retransmission after restarting is still a duplicate.
  assert_false(after.push(encoder.packet(32).unwrap()).unwrap())
  for id in 48..<76 {
    ignore(after.push(encoder.packet(id).unwrap()).unwrap())
  }
  assert_eq(after.decode().unwrap(), Some(data))
  assert_eq(before.progress().received, 16)
  assert_eq(before.decode().unwrap(), None)
  let completed = after.checkpoint()
  assert_eq(
    @rq.restore_decoder(completed).unwrap().decode().unwrap(),
    Some(data),
  )
  println(
    "resume: \{saved.length()} checkpoint bytes, 16 packets restored, exact recovery PASS",
  )
  println(
    "CRC32C checks storage corruption; it does not authenticate the object.",
  )
}
