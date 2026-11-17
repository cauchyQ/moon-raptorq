///|
/// RFC 6330 object profile with up to 16 source blocks, N=1 and Al=1.
/// Each block has at most 256 source symbols. This does not support sub-block
/// interleaving or the full standard's large-block parameter range.
pub struct ObjectConfig {
  priv length : Int32
  priv symbol_size : Int32
  priv blocks : Int32
  priv total_symbols : Int32
}

///|
pub fn ObjectConfig::new(
  length : Int32,
  symbol_size : Int32,
  blocks : Int32,
) -> Result[ObjectConfig, RaptorError] {
  if length <= 0 || symbol_size <= 0 {
    return Err(InvalidParameters("length and symbol size must be positive"))
  }
  if symbol_size > 4096 || blocks < 1 || blocks > 16 {
    return Err(
      ResourceLimit("object profile requires T<=4096 and 1..16 blocks"),
    )
  }
  let total_symbols = (length - 1) / symbol_size + 1
  if blocks > total_symbols {
    return Err(InvalidParameters("source blocks cannot be empty"))
  }
  if total_symbols > blocks * 256 {
    return Err(
      ResourceLimit("each source block must contain at most 256 symbols"),
    )
  }
  Ok({ length, symbol_size, blocks, total_symbols, })
}

///|
/// Choose the fewest blocks that keep every source block within K<=256.
pub fn ObjectConfig::automatic(
  length : Int32,
  symbol_size : Int32,
) -> Result[ObjectConfig, RaptorError] {
  if length <= 0 || symbol_size <= 0 {
    return Err(InvalidParameters("length and symbol size must be positive"))
  }
  let total = (length - 1) / symbol_size + 1
  let blocks = (total - 1) / 256 + 1
  ObjectConfig::new(length, symbol_size, blocks)
}

///|
pub fn ObjectConfig::transfer_length(self : ObjectConfig) -> Int32 {
  self.length
}

///|
pub fn ObjectConfig::symbol_size(self : ObjectConfig) -> Int32 {
  self.symbol_size
}

///|
pub fn ObjectConfig::source_blocks(self : ObjectConfig) -> Int32 {
  self.blocks
}

///|
/// Partition(Kt,Z): the first ZL blocks have KL=ceil(Kt/Z) symbols; the
/// remaining ZS blocks have KS=floor(Kt/Z). N=1 makes each block contiguous.
fn ObjectConfig::layout(
  self : ObjectConfig,
  block : Int32,
) -> Result[(Int32, Int32), RaptorError] {
  if block < 0 || block >= self.blocks {
    return Err(InvalidPacket("source block number outside object"))
  }
  let small = self.total_symbols / self.blocks
  let large_blocks = self.total_symbols % self.blocks
  let extra_before = if block < large_blocks { block } else { large_blocks }
  let symbol_offset = block * small + extra_before
  let count = small + (if block < large_blocks { 1 } else { 0 })
  let offset = symbol_offset * self.symbol_size
  let remaining = self.length - offset
  let length = if remaining < count * self.symbol_size {
    remaining
  } else {
    count * self.symbol_size
  }
  Ok((offset, length))
}

///|
pub fn ObjectConfig::block_offset(
  self : ObjectConfig,
  block : Int32,
) -> Result[Int32, RaptorError] {
  self.layout(block).map(layout => layout.0)
}

///|
pub fn ObjectConfig::block_config(
  self : ObjectConfig,
  block : Int32,
) -> Result[Config, RaptorError] {
  match self.layout(block) {
    Err(error) => Err(error)
    Ok((_, length)) => Config::new(length, self.symbol_size)
  }
}

///|
pub fn ObjectConfig::serialize(self : ObjectConfig) -> Bytes {
  let output = @buffer.Buffer::Buffer()
  output.write_byte(0)
  output.write_uint_be(self.length.reinterpret_as_uint())
  output.write_byte(0)
  output.write_uint16_be(self.symbol_size.to_uint16())
  output.write_byte(self.blocks.to_byte())
  output.write_uint16_be(1)
  output.write_byte(1)
  output.to_bytes()
}

///|
pub fn parse_object_config(bytes : Bytes) -> Result[ObjectConfig, RaptorError] {
  if bytes.length() != 12 {
    return Err(InvalidParameters("OTI must contain 12 bytes"))
  }
  if bytes[5] != 0 {
    return Err(InvalidParameters("reserved byte must be zero"))
  }
  if bytes[0] != 0 {
    return Err(ResourceLimit("object length exceeds bounded profile"))
  }
  if bytes[9] != 0 || bytes[10] != 1 || bytes[11] != 1 {
    return Err(UnsupportedProfile("object profile requires N=1 and Al=1"))
  }
  let length = bytes.unsafe_read_uint32_be(1)
  if length > 16777216U {
    return Err(ResourceLimit("object length exceeds 16 MiB"))
  }
  ObjectConfig::new(
    length.reinterpret_as_int(),
    bytes.unsafe_read_uint16_be(6).to_int(),
    bytes[8].to_int(),
  )
}
