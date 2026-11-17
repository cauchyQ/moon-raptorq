///|
/// Offline channel descriptions shared by all algorithms in the comparison.
/// These are experimental workloads, not measurements from deployed networks.
pub(all) struct Scenario {
  name : String
  symbols : Int32
  width : Int32
  budget : Int32
  receivers : Int32
  loss_percent : Int32
  burst_start : Int32
  burst_length : Int32
  duplicate_every : Int32
  reverse : Bool
}

///|
pub fn scenarios() -> Array[Scenario] {
  [
    {
      name: "multicast",
      symbols: 32,
      width: 128,
      budget: 64,
      receivers: 6,
      loss_percent: 20,
      burst_start: 0,
      burst_length: 0,
      duplicate_every: 0,
      reverse: false,
    },
    {
      name: "intermittent-device",
      symbols: 64,
      width: 128,
      budget: 112,
      receivers: 1,
      loss_percent: 10,
      burst_start: 16,
      burst_length: 24,
      duplicate_every: 7,
      reverse: false,
    },
    {
      name: "edge-handoff",
      symbols: 64,
      width: 64,
      budget: 112,
      receivers: 1,
      loss_percent: 25,
      burst_start: 0,
      burst_length: 0,
      duplicate_every: 5,
      reverse: true,
    },
  ]
}

///|
pub fn source(length : Int32, seed : UInt32) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  let mut state = seed
  for _ in 0..<length {
    state = state * 1664525U + 1013904223U
    output.write_byte((state >> 24).to_byte())
  }
  output.to_bytes()
}

///|
/// Trace entries are packet sequence numbers; repeated entries model network
/// duplicates. All algorithms replay exactly this sequence for the same seed.
pub fn trace(
  scenario : Scenario,
  seed : UInt32,
  receiver : Int32,
) -> Array[Int32] {
  let entries : Array[Int32] = []
  let mut state = seed + (receiver + 1).reinterpret_as_uint() * 2654435761U
  for sequence in 0..<scenario.budget {
    state = state * 1664525U + 1013904223U
    let random_loss = (state % 100U).reinterpret_as_int() <
      scenario.loss_percent
    let burst_loss = sequence >= scenario.burst_start &&
      sequence < scenario.burst_start + scenario.burst_length
    if !random_loss && !burst_loss {
      entries.push(sequence)
      if scenario.duplicate_every > 0 &&
        sequence % scenario.duplicate_every == 0 {
        entries.push(sequence)
      }
    }
  }
  if scenario.reverse {
    entries.rev_in_place()
  }
  entries
}

///|
pub fn padded_symbols(
  data : Bytes,
  count : Int32,
  width : Int32,
) -> Array[Bytes] {
  let result : Array[Bytes] = []
  for index in 0..<count {
    let symbol = @buffer.Buffer::Buffer()
    for byte in 0..<width {
      let offset = index * width + byte
      symbol.write_byte(if offset < data.length() { data[offset] } else { 0 })
    }
    result.push(symbol.to_bytes())
  }
  result
}

///|
pub fn join_symbols(symbols : Array[Bytes], length : Int32) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  for symbol in symbols {
    for byte in symbol {
      if output.length() < length {
        output.write_byte(byte)
      }
    }
  }
  output.to_bytes()
}

///|
pub fn unique_entries(entries : Array[Int32], budget : Int32) -> Int32 {
  let seen = Array::make(budget, false)
  let mut count = 0
  for entry in entries {
    if !seen[entry] {
      seen[entry] = true
      count += 1
    }
  }
  count
}

///|
/// Common machine-readable rows. Time excludes source generation and trace
/// creation. Packet generation and serialization are in encode_us; receive
/// parsing, retention and recovery are in decode_us. Startup/JIT is excluded.
pub fn measurement(
  algorithm : String,
  scenario : Scenario,
  repetition : Int32,
  receiver : Int32,
  encode_us : Double,
  decode_us : Double,
  sent_bytes : Int32,
  received_bytes : Int32,
  received : Int32,
  unique : Int32,
  recovered : Bool,
  rank~ : Int32 = -1,
) -> Json {
  @json.Json::object({
    "algorithm": @json.Json::string(algorithm),
    "scenario": @json.Json::string(scenario.name),
    "repetition": @json.Json::number(repetition.to_double()),
    "receiver": @json.Json::number(receiver.to_double()),
    "K": @json.Json::number(scenario.symbols.to_double()),
    "T": @json.Json::number(scenario.width.to_double()),
    "budget": @json.Json::number(scenario.budget.to_double()),
    "object_bytes": @json.Json::number(
      (scenario.symbols * scenario.width - 1).to_double(),
    ),
    "encode_us": @json.Json::number(encode_us),
    "decode_us": @json.Json::number(decode_us),
    "sent_bytes": @json.Json::number(sent_bytes.to_double()),
    "received_bytes": @json.Json::number(received_bytes.to_double()),
    "received_packets": @json.Json::number(received.to_double()),
    "unique_packets": @json.Json::number(unique.to_double()),
    "recovered": @json.Json::boolean(recovered),
    "rank": @json.Json::number(rank.to_double()),
  })
}
