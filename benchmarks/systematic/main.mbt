///|
fn main raise {
  for k in [16, 64, 256] {
    let data = @lab.source(k * 128 - 1, 123U)
    let encoder = @rq.Encoder::new(data, 128).unwrap()
    let decoder = @rq.Decoder::new(encoder.config())
    let mut id = k - 1
    while id >= 0 {
      ignore(decoder.push(encoder.packet(id).unwrap()).unwrap())
      id -= 1
    }
    for repetition in -1..<5 {
      let started = @bench.monotonic_clock_start()
      let result = decoder.decode().unwrap()
      let elapsed = @bench.monotonic_clock_end(started)
      assert_eq(result, Some(data))
      println(
        "{\"K\":\{k},\"T\":128,\"repetition\":\{repetition},\"decode_us\":\{elapsed}}",
      )
    }
  }
}
