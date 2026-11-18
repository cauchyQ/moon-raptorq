///|
/// RFC 6330 metadata, independent of an individual codec's memory budget.
/// Maximum F follows erratum 5548 (255 representable source blocks).
pub struct TransmissionInfo {
  priv length : Int64
  priv size : Int32
  priv blocks : Int32
  priv subblocks : Int32
  priv alignment : Int32
}

///|
pub fn TransmissionInfo::new(
  length : Int64,
  symbol_size : Int32,
  source_blocks : Int32,
  sub_blocks : Int32,
  alignment : Int32,
) -> Result[TransmissionInfo, RaptorError] {
  if length < 0L || length > 942574504275L {
    return Err(InvalidParameters("F outside RFC 6330 erratum 5548 range"))
  }
  if symbol_size < 1 ||
    symbol_size > 65535 ||
    source_blocks < 1 ||
    source_blocks > 255 ||
    sub_blocks < 1 ||
    sub_blocks > 65535 ||
    alignment < 1 ||
    alignment > 255 {
    return Err(InvalidParameters("invalid OTI field range"))
  }
  if symbol_size % alignment != 0 {
    return Err(InvalidParameters("T must be a multiple of Al"))
  }
  let total = (length + symbol_size.to_int64() - 1L) / symbol_size.to_int64()
  if (total + source_blocks.to_int64() - 1L) / source_blocks.to_int64() > 56403L {
    return Err(InvalidParameters("source block exceeds Kmax=56403"))
  }
  Ok({
    length,
    size: symbol_size,
    blocks: source_blocks,
    subblocks: sub_blocks,
    alignment,
  })
}

///|
pub fn TransmissionInfo::transfer_length(self : TransmissionInfo) -> Int64 {
  self.length
}

///|
pub fn TransmissionInfo::symbol_size(self : TransmissionInfo) -> Int32 {
  self.size
}

///|
pub fn TransmissionInfo::source_blocks(self : TransmissionInfo) -> Int32 {
  self.blocks
}

///|
pub fn TransmissionInfo::sub_blocks(self : TransmissionInfo) -> Int32 {
  self.subblocks
}

///|
pub fn TransmissionInfo::alignment(self : TransmissionInfo) -> Int32 {
  self.alignment
}

///|
pub fn TransmissionInfo::serialize(self : TransmissionInfo) -> Bytes {
  let out = @buffer.Buffer::Buffer()
  for shift in [32, 24, 16, 8, 0] {
    out.write_byte(((self.length >> shift) & 255L).to_int().to_byte())
  }
  out.write_byte(0)
  out.write_uint16_be(self.size.to_uint16())
  out.write_byte(self.blocks.to_byte())
  out.write_uint16_be(self.subblocks.to_uint16())
  out.write_byte(self.alignment.to_byte())
  out.to_bytes()
}

///|
pub fn parse_transmission_info(
  bytes : Bytes,
) -> Result[TransmissionInfo, RaptorError] {
  if bytes.length() != 12 || bytes[5] != 0 {
    return Err(
      InvalidParameters("OTI requires 12 bytes and a zero reserved field"),
    )
  }
  let mut length = 0L
  for i in 0..<5 {
    length = (length << 8) + bytes[i].to_int().to_int64()
  }
  TransmissionInfo::new(
    length,
    bytes.unsafe_read_uint16_be(6).to_int(),
    bytes[8].to_int(),
    bytes.unsafe_read_uint16_be(9).to_int(),
    bytes[11].to_int(),
  )
}

///|
/// Offsets are Int64 so a valid large object never wraps at 2 GiB.
pub(all) struct SourceBlockLayout {
  offset : Int64
  padded_length : Int64
  data_length : Int64
  symbols : Int32
}

///|
pub fn TransmissionInfo::block_layout(
  self : TransmissionInfo,
  block : Int32,
) -> Result[SourceBlockLayout, RaptorError] {
  if block < 0 || block >= self.blocks {
    return Err(InvalidParameters("source block index outside OTI"))
  }
  let total = (self.length + self.size.to_int64() - 1L) / self.size.to_int64()
  let small = total / self.blocks.to_int64()
  let large = (total % self.blocks.to_int64()).to_int()
  let before = if block < large { block } else { large }
  let offset = (block.to_int64() * small + before.to_int64()) *
    self.size.to_int64()
  let symbols = small.to_int() + (if block < large { 1 } else { 0 })
  let padded_length = symbols.to_int64() * self.size.to_int64()
  let remaining = self.length - offset
  let data_length = if remaining < 0L {
    0L
  } else if remaining < padded_length {
    remaining
  } else {
    padded_length
  }
  Ok({ offset, padded_length, data_length, symbols, })
}

///|
pub(all) struct SubBlockLayout {
  offset : Int64
  length : Int64
  symbol_offset : Int32
  subsymbol_size : Int32
}

///|
/// Partition(T/Al,N), followed by K contiguous sub-symbols per sub-block.
pub fn TransmissionInfo::subblock_layout(
  self : TransmissionInfo,
  block : Int32,
  subblock : Int32,
) -> Result[SubBlockLayout, RaptorError] {
  let layout = match self.block_layout(block) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if subblock < 0 || subblock >= self.subblocks {
    return Err(InvalidParameters("sub-block index outside OTI"))
  }
  let units = self.size / self.alignment
  let small = units / self.subblocks
  let large = units % self.subblocks
  let before = if subblock < large { subblock } else { large }
  let symbol_offset = (subblock * small + before) * self.alignment
  let subsymbol_size = (small + (if subblock < large { 1 } else { 0 })) *
    self.alignment
  Ok({
    offset: layout.offset + layout.symbols.to_int64() * symbol_offset.to_int64(),
    length: layout.symbols.to_int64() * subsymbol_size.to_int64(),
    symbol_offset,
    subsymbol_size,
  })
}

///|
/// Gather one source symbol from a caller-owned, padded source block. This
/// performs the normative sub-block interleaving, not a contiguous T-byte slice.
pub fn TransmissionInfo::source_symbol(
  self : TransmissionInfo,
  block : Int32,
  source : Bytes,
  id : Int32,
) -> Result[Bytes, RaptorError] {
  let layout = match self.block_layout(block) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if source.length().to_int64() != layout.padded_length ||
    id < 0 ||
    id >= layout.symbols {
    return Err(
      InvalidParameters("padded source block or symbol index mismatch"),
    )
  }
  let out = @buffer.Buffer::Buffer()
  for sub in 0..<self.subblocks {
    let part = self.subblock_layout(block, sub).unwrap()
    let start = (part.offset - layout.offset).to_int() +
      id * part.subsymbol_size
    out.write_bytes(source[start:start + part.subsymbol_size])
  }
  Ok(out.to_bytes())
}

///|
/// Scatter recovered symbols back to source-block order; discard only the
/// normative zero padding at the very end of the final source block.
pub fn TransmissionInfo::reassemble_block(
  self : TransmissionInfo,
  block : Int32,
  symbols : Array[Bytes],
) -> Result[Bytes, RaptorError] {
  let layout = match self.block_layout(block) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  if layout.padded_length > 2147483647L {
    return Err(
      ResourceLimit(
        "source block exceeds host byte indexing; use sub-block processing",
      ),
    )
  }
  if symbols.length() != layout.symbols {
    return Err(InvalidParameters("source symbol count mismatch"))
  }
  for symbol in symbols {
    if symbol.length() != self.size {
      return Err(InvalidParameters("source symbol size mismatch"))
    }
  }
  let out = @buffer.Buffer::Buffer()
  for sub in 0..<self.subblocks {
    let part = self.subblock_layout(block, sub).unwrap()
    for symbol in symbols {
      out.write_bytes(
        symbol[part.symbol_offset:part.symbol_offset + part.subsymbol_size],
      )
    }
  }
  let bytes = out.to_bytes()
  return Ok(bytes[:layout.data_length.to_int()].to_owned())
}

///|
pub(all) struct BlockParameters {
  extended_symbols : Int32
  systematic_index : Int32
  ldpc_symbols : Int32
  hdpc_symbols : Int32
  lt_symbols : Int32
  intermediate_symbols : Int32
}

///|
pub fn block_parameters(k : Int32) -> Result[BlockParameters, RaptorError] {
  if k < 1 || k > 56403 {
    return Err(InvalidParameters("K must be 1..56403"))
  }
  let p = parameters(k)
  Ok({
    extended_symbols: p.extended,
    systematic_index: p.systematic,
    ldpc_symbols: p.ldpc,
    hdpc_symbols: p.hdpc,
    lt_symbols: p.lt,
    intermediate_symbols: p.total,
  })
}
