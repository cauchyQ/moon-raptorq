///|
fn raptorq(
  scenario : @lab.Scenario,
  repetition : Int32,
  streaming : Bool,
) -> Unit {
  let data = @lab.source(scenario.symbols * scenario.width - 1, 20261117U)
  let started = @bench.monotonic_clock_start()
  let encoder = @rq.Encoder::new(data, scenario.width).unwrap()
  let packets : Array[Bytes] = []
  let mut sent = 12 // The out-of-band standard OTI is sent once.
  for sequence in 0..<scenario.budget {
    let packet = encoder.packet(sequence).unwrap().serialize()
    packets.push(packet)
    sent += packet.length()
  }
  let encode_us = @bench.monotonic_clock_end(started)
  for receiver in 0..<scenario.receivers {
    let trace = @lab.trace(
      scenario,
      (20261117 + repetition).reinterpret_as_uint(),
      receiver,
    )
    let unique = @lab.unique_entries(trace, scenario.budget)
    let started = @bench.monotonic_clock_start()
    let config = @rq.parse_config(encoder.config().serialize()).unwrap()
    let mut received_bytes = 12
    let recovered = if streaming {
      let decoder = @rq.StreamDecoder::new(config)
      for sequence in trace {
        received_bytes += packets[sequence].length()
        ignore(decoder.push_bytes(packets[sequence]).unwrap())
      }
      decoder.decode().unwrap() == Some(data)
    } else {
      let decoder = @rq.Decoder::new(config)
      for sequence in trace {
        received_bytes += packets[sequence].length()
        ignore(decoder.push_bytes(packets[sequence]).unwrap())
      }
      decoder.decode().unwrap() == Some(data)
    }
    let decode_us = @bench.monotonic_clock_end(started)
    let algorithm = if streaming {
      "MoonRaptorQ-stream"
    } else {
      "MoonRaptorQ-batch"
    }
    println(
      @lab.measurement(
        algorithm,
        scenario,
        repetition,
        receiver,
        encode_us,
        decode_us,
        sent,
        received_bytes,
        trace.length(),
        unique,
        recovered,
      ).stringify(),
    )
  }
}

///|
fn reed_solomon(scenario : @lab.Scenario, repetition : Int32) -> Unit raise {
  let data = @lab.source(scenario.symbols * scenario.width - 1, 20261117U)
  let started = @bench.monotonic_clock_start()
  let codec = @rs.Codec::new(
    scenario.symbols,
    scenario.budget - scenario.symbols,
  )
  let object = @rs.encode_object(
    codec,
    data,
    17,
    stripe_payload_limit=data.length(),
  )
  assert_eq(object.frame_count(), scenario.budget)
  let packets = object.frames().map(frame => frame.to_bytes())
  let manifest = object.manifest().to_bytes()
  let mut sent = manifest.length()
  for packet in packets {
    sent += packet.length()
  }
  let encode_us = @bench.monotonic_clock_end(started)
  for receiver in 0..<scenario.receivers {
    let trace = @lab.trace(
      scenario,
      (20261117 + repetition).reinterpret_as_uint(),
      receiver,
    )
    let unique = @lab.unique_entries(trace, scenario.budget)
    let started = @bench.monotonic_clock_start()
    let config = @rs.Manifest::from_bytes(manifest)
    let mut received_bytes = manifest.length()
    let received : Array[Bytes] = []
    let seen = Array::make(scenario.budget, false)
    for sequence in trace {
      received_bytes += packets[sequence].length()
      // MoonErasure rejects duplicate indices. The transport adapter performs
      // deduplication, with its work and duplicate bytes included in the row.
      if !seen[sequence] {
        received.push(packets[sequence])
        seen[sequence] = true
      }
    }
    let recovered = try
      @rs.recover_serialized_object(config, received).recovery().payload() ==
      data
    catch {
      @rs.NotEnoughShards(..) => false
      error => raise error
    }
    let decode_us = @bench.monotonic_clock_end(started)
    println(
      @lab.measurement(
        "MoonErasure-0.3.0",
        scenario,
        repetition,
        receiver,
        encode_us,
        decode_us,
        sent,
        received_bytes,
        trace.length(),
        unique,
        recovered,
      ).stringify(),
    )
  }
}

///|
fn random_linear(scenario : @lab.Scenario, repetition : Int32) -> Unit raise {
  let data = @lab.source(scenario.symbols * scenario.width - 1, 20261117U)
  let started = @bench.monotonic_clock_start()
  let encoder = @rlnc.Encoder::new(
    17,
    @rlnc.Symbols::from_bytes(data),
    scenario.width,
  )
  let stream = @rlnc.CoefficientStream::new(20261117U)
  let packets : Array[@rlnc.Symbols] = []
  let mut sent = 0
  for sequence in 0..<scenario.budget {
    let packet = if sequence < scenario.symbols {
      encoder.systematic(sequence, sequence)
    } else {
      encoder.coded(stream, sequence)
    }
    let wire = packet.to_wire()
    packets.push(wire)
    sent += wire.length()
  }
  let encode_us = @bench.monotonic_clock_end(started)
  for receiver in 0..<scenario.receivers {
    let trace = @lab.trace(
      scenario,
      (20261117 + repetition).reinterpret_as_uint(),
      receiver,
    )
    let unique = @lab.unique_entries(trace, scenario.budget)
    let started = @bench.monotonic_clock_start()
    let decoder = @rlnc.Decoder::new(
      encoder.generation(),
      max_packets=2 * scenario.budget,
    )
    let mut received_bytes = 0
    for sequence in trace {
      received_bytes += packets[sequence].length()
      ignore(decoder.admit(@rlnc.packet_from_wire(packets[sequence])))
    }
    let recovered = if decoder.rank() == scenario.symbols {
      decoder.recover().to_bytes() == data
    } else {
      false
    }
    let decode_us = @bench.monotonic_clock_end(started)
    println(
      @lab.measurement(
        "MoonRecoder-0.1.1",
        scenario,
        repetition,
        receiver,
        encode_us,
        decode_us,
        sent,
        received_bytes,
        trace.length(),
        unique,
        recovered,
        rank=decoder.rank(),
      ).stringify(),
    )
  }
}

///|
fn main raise {
  // One unreported warmup initializes field tables and runtime code paths.
  // Report script discards repetition -1, retaining all five measured runs.
  for repetition in -1..<5 {
    for scenario in @lab.scenarios() {
      raptorq(scenario, repetition, true)
      raptorq(scenario, repetition, false)
      reed_solomon(scenario, repetition)
      random_linear(scenario, repetition)
    }
  }
}
