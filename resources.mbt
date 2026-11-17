///|
/// Raw numeric storage for the supported streaming profile. Array headers,
/// allocator overhead, input ownership and runtime GC space are not included.
pub(all) struct StorageEstimate {
  coefficient_bytes : Int32
  symbol_bytes : Int32
  retained_payload_bytes : Int32
  decode_scratch_bytes : Int32
  shared_field_table_bytes : Int32
}

///|
pub fn StorageEstimate::raw_total(self : StorageEstimate) -> Int32 {
  self.coefficient_bytes +
  self.symbol_bytes +
  self.retained_payload_bytes +
  self.decode_scratch_bytes +
  self.shared_field_table_bytes
}

///|
/// Conservative raw-element bound when K+64 packets have been retained and a
/// full-rank decode is in progress. This is not a measured process peak RSS.
pub fn Config::stream_storage(self : Config) -> StorageEstimate {
  let p = parameters(self.source_symbols)
  {
    coefficient_bytes: 4 * p.total * p.total,
    symbol_bytes: 4 * p.total * self.symbol_size,
    retained_payload_bytes: (self.source_symbols + 64) * self.symbol_size,
    decode_scratch_bytes: 4 * p.total * self.symbol_size +
    self.length +
    4 * self.symbol_size,
    shared_field_table_bytes: 256 * 256 * 4,
  }
}

///|
pub fn RaptorError::message(self : RaptorError) -> String {
  match self {
    InvalidParameters(message) => "invalid parameters: " + message
    UnsupportedProfile(message) => "unsupported profile: " + message
    InvalidPacket(message) => "invalid packet: " + message
    ResourceLimit(message) => "resource limit: " + message
    ConflictingDuplicate(id) => "conflicting duplicate ESI " + id.to_string()
    InconsistentEquations => "inconsistent encoding equations"
  }
}
