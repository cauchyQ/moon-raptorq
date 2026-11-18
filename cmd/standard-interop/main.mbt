///|
fn main raise {
  let counts = if @env.get_env_var("RAPTORQ_STANDARD_QUICK") == Some("1") {
    [257, 1024, 4096]
  } else {
    [257, 1024, 4096, 56403]
  }
  for k in counts {
    let source = Array::makei(k, i => {
      let value = (i * 17 + 11) % 256
      @hex.decode(
        if value < 16 {
          "0" + value.to_string(radix=16)
        } else {
          value.to_string(radix=16)
        },
      )
    })
    let start = @bench.monotonic_clock_start()
    let limits = @rq.ExecutionLimits::new(sparse_entries=33554432).unwrap()
    let encoder = match @rq.StandardBlockEncoder::new(source, limits~) {
      Ok(value) => value
      Err(error) => abort("K=\{k} encoder: " + error.message())
    }
    let encode_us = @bench.monotonic_clock_end(start)
    let receiver = @rq.StandardBlockDecoder::new(k, 1, limits~).unwrap()
    for id in 0..<k {
      if id % 10 != 0 {
        receiver.push(id, source[id]).unwrap() |> ignore
      }
    }
    let reference = @env.get_env_var("RAPTORQ_RUST_" + k.to_string()).unwrap_or(
      "",
    )
    let mut repairs_hex = ""
    for id in k..<(k + (k + 9) / 10 + 16) {
      let payload = encoder.symbol(id).unwrap()
      repairs_hex += @hex.encode(payload[:])
      let incoming = if reference.is_empty() {
        payload
      } else {
        @hex.decode(reference[(id - k) * 2:(id - k + 1) * 2].to_owned())
      }
      assert_eq(incoming, payload)
      receiver.push(id, incoming).unwrap() |> ignore
    }
    let start = @bench.monotonic_clock_start()
    let recovered = match receiver.decode() {
      Ok(Some(value)) => value
      Ok(None) => abort("K=\{k}: insufficient rank")
      Err(error) => abort("K=\{k} decoder: " + error.message())
    }
    let decode_us = @bench.monotonic_clock_end(start)
    assert_eq(recovered, source) catch {
      _ => abort("large-block recovery mismatch")
    }
    let a = @hex.encode(encoder.symbol(k).unwrap()[:])
    let b = @hex.encode(encoder.symbol(16777215).unwrap()[:])
    println(
      "{\"k\":\{k},\"t\":1,\"encode_us\":\{encode_us},\"decode_us\":\{decode_us},\"repair\":\"\{a}\",\"high_esi\":\"\{b}\",\"recovered\":true,\"repairs_hex\":\"\{repairs_hex}\"}",
    )
  }
}
