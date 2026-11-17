///|
fn measure(k : Int32, width : Int32, repetition : Int32) -> Unit raise {
  let source = @lab.source(k * width - 1, 20261117U)
  let started = @bench.monotonic_clock_start()
  let direct = @rq.Encoder::new(source, width).unwrap()
  let direct_us = @bench.monotonic_clock_end(started)
  let started = @bench.monotonic_clock_start()
  let plan = @rq.EncodingPlan::new(k).unwrap()
  let plan_build_us = @bench.monotonic_clock_end(started)
  let started = @bench.monotonic_clock_start()
  let planned = plan.encode(source, width).unwrap()
  let planned_us = @bench.monotonic_clock_end(started)
  let packets : Array[@rq.Packet] = []
  let started = @bench.monotonic_clock_start()
  for id in k..<(2 * k + 8) {
    packets.push(direct.packet(id).unwrap())
  }
  let repairs_us = @bench.monotonic_clock_end(started)
  for id in [0, k - 1, k, k + 7, 16777215] {
    assert_eq(
      direct.packet(id).unwrap().serialize(),
      planned.packet(id).unwrap().serialize(),
    )
  }
  let batch = @rq.Decoder::new(direct.config())
  let started = @bench.monotonic_clock_start()
  for packet in packets {
    ignore(batch.push(packet).unwrap())
  }
  assert_eq(batch.decode().unwrap(), Some(source))
  let batch_us = @bench.monotonic_clock_end(started)
  let started = @bench.monotonic_clock_start()
  let stream = @rq.StreamDecoder::new(direct.config())
  for packet in packets {
    ignore(stream.push(packet).unwrap())
  }
  assert_eq(stream.decode().unwrap(), Some(source))
  let stream_us = @bench.monotonic_clock_end(started)
  let estimate = direct.config().stream_storage()
  println(
    @json.Json::object({
      "K": @json.Json::number(k.to_double()),
      "T": @json.Json::number(width.to_double()),
      "repetition": @json.Json::number(repetition.to_double()),
      "direct_encoder_us": @json.Json::number(direct_us),
      "plan_build_us": @json.Json::number(plan_build_us),
      "planned_encoder_us": @json.Json::number(planned_us),
      "repair_generation_us": @json.Json::number(repairs_us),
      "batch_decode_us": @json.Json::number(batch_us),
      "stream_decode_us": @json.Json::number(stream_us),
      "plan_coefficient_bytes": @json.Json::number(
        plan.coefficient_bytes().to_double(),
      ),
      "stream_raw_storage_bound": @json.Json::number(
        estimate.raw_total().to_double(),
      ),
    }).stringify(),
  )
}

///|
fn overhead(k : Int32, seed : UInt32) -> Unit raise {
  let data = @lab.source(k * 8 - 1, seed)
  let encoder = @rq.Encoder::new(data, 8).unwrap()
  let stream = @rq.StreamDecoder::new(encoder.config())
  let first = k + (seed % 100000U).reinterpret_as_int()
  let mut completion = -1
  let checkpoints : Array[Json] = []
  for offset in 0..<(k + 9) {
    ignore(stream.push(encoder.packet(first + offset).unwrap()).unwrap())
    let received = offset + 1
    if stream.progress().complete() && completion < 0 {
      completion = received
    }
    if received == k ||
      received == k + 1 ||
      received == k + 2 ||
      received == k + 4 ||
      received == k + 8 {
      checkpoints.push(
        @json.Json::object({
          "extra": @json.Json::number((received - k).to_double()),
          "rank": @json.Json::number(stream.progress().independent.to_double()),
        }),
      )
    }
  }
  if completion >= 0 {
    assert_eq(stream.decode().unwrap(), Some(data))
  }
  println(
    @json.Json::object({
      "kind": @json.Json::string("repair-only-overhead"),
      "K": @json.Json::number(k.to_double()),
      "seed": @json.Json::number(seed.reinterpret_as_int().to_double()),
      "first_ESI": @json.Json::number(first.to_double()),
      "completion_packets": @json.Json::number(completion.to_double()),
      "checkpoints": @json.Json::array(checkpoints),
    }).stringify(),
  )
}

///|
fn main raise {
  // Small sizes include padding transitions; large sizes exercise both limits
  // of the supported dense profile. Plan construction is never hidden in the
  // per-object planned-encoder timing.
  for repetition in -1..<3 {
    for k in [16, 64, 128, 256] {
      for width in [8, 128, 1024] {
        measure(k, width, repetition)
      }
    }
  }
  for k in [16, 32, 64] {
    for trial in 0..<64 {
      overhead(k, (20261117 + trial * 104729).reinterpret_as_uint())
    }
  }
}
