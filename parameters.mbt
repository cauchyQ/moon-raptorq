///|
/// Explicit limits for the dense reference solver.
pub(all) enum RaptorError {
  InvalidParameters(String)
  UnsupportedProfile(String)
  InvalidPacket(String)
  ResourceLimit(String)
  ConflictingDuplicate(Int32)
  InconsistentEquations
}

///|
/// Validated single-block, single-subblock RFC 6330 profile.
pub struct Config {
  priv length : Int32
  priv symbol_size : Int32
  priv source_symbols : Int32
}

///|
/// Small bounded profile: 1..256 source symbols, 1..4096 bytes per symbol.
pub fn Config::new(
  length : Int32,
  symbol_size : Int32,
) -> Result[Config, RaptorError] {
  if length <= 0 || symbol_size <= 0 {
    return Err(InvalidParameters("length and symbol size must be positive"))
  }
  if symbol_size > 4096 || length > 256 * symbol_size {
    return Err(ResourceLimit("maximum K=256 and T=4096"))
  }
  let source_symbols = (length - 1) / symbol_size + 1
  Ok({ length, symbol_size, source_symbols, })
}

///|
pub fn Config::transfer_length(self : Config) -> Int32 {
  self.length
}

///|
pub fn Config::symbol_size(self : Config) -> Int32 {
  self.symbol_size
}

///|
pub fn Config::source_symbols(self : Config) -> Int32 {
  self.source_symbols
}

///|
priv struct Parameters {
  extended : Int32
  systematic : Int32
  ldpc : Int32
  hdpc : Int32
  lt : Int32
  total : Int32
  pi : Int32
  prime : Int32
}

///|
fn parameters(count : Int32) -> Parameters {
  for entry in systematic_parameters {
    let (extended, systematic, ldpc, hdpc, lt) = entry
    if extended >= count {
      let total = extended + ldpc + hdpc
      let pi = total - lt
      let mut prime = pi
      while !is_prime(prime) {
        prime += 1
      }
      return { extended, systematic, ldpc, hdpc, lt, total, pi, prime, }
    }
  }
  abort("validated profile has no parameter table entry")
}

///|
fn is_prime(value : Int32) -> Bool {
  if value < 2 {
    return false
  }
  let mut divisor = 2
  while divisor * divisor <= value {
    if value % divisor == 0 {
      return false
    }
    divisor += 1
  }
  true
}

///|
/// RFC 6330 Rand[y,i,m], using standard unsigned wrapping arithmetic.
fn standard_random(y : UInt32, index : Int32, modulus : Int32) -> Int32 {
  let i = index.reinterpret_as_uint()
  let a = ((y + i) & 255U).reinterpret_as_int()
  let b = (((y >> 8) + i) & 255U).reinterpret_as_int()
  let c = (((y >> 16) + i) & 255U).reinterpret_as_int()
  let d = (((y >> 24) + i) & 255U).reinterpret_as_int()
  ((random_v0[a] ^ random_v1[b] ^ random_v2[c] ^ random_v3[d]) %
  modulus.reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// RFC 6330 Tuple and Enc index generation.
fn encoding_indices(p : Parameters, internal_id : Int32) -> Array[Int32] {
  let mut multiplier = 53591 + p.systematic * 997
  if multiplier % 2 == 0 {
    multiplier += 1
  }
  let y = (10267 * (p.systematic + 1)).reinterpret_as_uint() +
    internal_id.reinterpret_as_uint() * multiplier.reinterpret_as_uint()
  let thresholds = [
    0, 5243, 529531, 704294, 791675, 844104, 879057, 904023, 922747, 937311, 948962,
    958494, 966438, 973160, 978921, 983914, 988283, 992138, 995565, 998631, 1001391,
    1003887, 1006157, 1008229, 1010129, 1011876, 1013490, 1014983, 1016370, 1017662,
    1048576,
  ]
  let v = standard_random(y, 0, 1048576)
  let mut degree = 1
  while v >= thresholds[degree] {
    degree += 1
  }
  if degree > p.lt - 2 {
    degree = p.lt - 2
  }
  let step = 1 + standard_random(y, 1, p.lt - 1)
  let mut position = standard_random(y, 2, p.lt)
  let output = [position]
  for _ in 1..<degree {
    position = (position + step) % p.lt
    output.push(position)
  }
  let id = internal_id.reinterpret_as_uint()
  let pi_degree = if degree < 4 { 2 + standard_random(id, 3, 2) } else { 2 }
  let pi_step = 1 + standard_random(id, 4, p.prime - 1)
  let mut pi_position = standard_random(id, 5, p.prime)
  for _ in 0..<pi_degree {
    while pi_position >= p.pi {
      pi_position = (pi_position + pi_step) % p.prime
    }
    output.push(p.lt + pi_position)
    pi_position = (pi_position + pi_step) % p.prime
  }
  output
}
