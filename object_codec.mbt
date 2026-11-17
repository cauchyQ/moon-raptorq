///|
/// Stores the original object and constructs one source-block encoder on
/// request. Callers can release that encoder before moving to the next block.
pub struct ObjectEncoder {
  priv config : ObjectConfig
  priv data : Bytes
}

///|
pub fn ObjectEncoder::new(
  data : Bytes,
  symbol_size : Int32,
  blocks : Int32,
) -> Result[ObjectEncoder, RaptorError] {
  match ObjectConfig::new(data.length(), symbol_size, blocks) {
    Err(error) => Err(error)
    Ok(config) => Ok({ config, data, })
  }
}

///|
pub fn ObjectEncoder::config(self : ObjectEncoder) -> ObjectConfig {
  self.config
}

///|
pub fn ObjectEncoder::block(
  self : ObjectEncoder,
  index : Int32,
) -> Result[Encoder, RaptorError] {
  match self.config.layout(index) {
    Err(error) => Err(error)
    Ok((offset, length)) =>
      Encoder::new(
        self.data[offset:offset + length].to_owned(),
        self.config.symbol_size,
      )
  }
}

///|
/// Completed blocks retain only recovered bytes and release the elimination
/// basis. An explicit active-block budget prevents interleaved arrivals from
/// allocating all block matrices at once. Completed blocks ignore late packets;
/// authentication and object identity remain the surrounding protocol's job.
pub struct ObjectDecoder {
  priv config : ObjectConfig
  priv active_limit : Int32
  priv decoders : Array[StreamDecoder?]
  priv completed : Array[Bytes?]
  priv counts : Array[Int32]
  priv mut active : Int32
  priv mut done : Int32
}

///|
pub fn ObjectDecoder::new(
  config : ObjectConfig,
  max_active_blocks~ : Int32 = 4,
) -> Result[ObjectDecoder, RaptorError] {
  if max_active_blocks < 1 || max_active_blocks > 16 {
    return Err(ResourceLimit("active block budget must be 1..16"))
  }
  Ok({
    config,
    active_limit: max_active_blocks,
    decoders: Array::make(config.blocks, None),
    completed: Array::make(config.blocks, None),
    counts: Array::make(config.blocks, 0),
    active: 0,
    done: 0,
  })
}

///|
pub fn ObjectDecoder::completed_blocks(self : ObjectDecoder) -> Int32 {
  self.done
}

///|
pub fn ObjectDecoder::active_blocks(self : ObjectDecoder) -> Int32 {
  self.active
}

///|
/// New symbols update one block. Completing a block performs one back
/// substitution and releases its dense state. Late packets for it return false.
pub fn ObjectDecoder::push(
  self : ObjectDecoder,
  packet : ObjectPacket,
) -> Result[Bool, RaptorError] {
  let index = packet.block
  match self.config.packet(index, packet.symbol) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if self.completed[index] is Some(_) {
    return Ok(false)
  }
  let decoder = match self.decoders[index] {
    Some(decoder) => decoder
    None => {
      if self.active >= self.active_limit {
        return Err(ResourceLimit("active source-block budget exhausted"))
      }
      let decoder = StreamDecoder::new(self.config.block_config(index).unwrap())
      decoder
    }
  }
  match decoder.push(packet.symbol) {
    Err(error) => return Err(error)
    Ok(false) => return Ok(false)
    Ok(true) => ()
  }
  if self.decoders[index] is None {
    self.decoders[index] = Some(decoder)
    self.active += 1
  }
  self.counts[index] += 1
  if decoder.progress().complete() {
    match decoder.decode() {
      Err(error) => return Err(error)
      Ok(None) => return Err(InconsistentEquations)
      Ok(Some(data)) => {
        self.completed[index] = Some(data)
        self.decoders[index] = None
        self.active -= 1
        self.done += 1
      }
    }
  }
  Ok(true)
}

///|
pub fn ObjectDecoder::push_bytes(
  self : ObjectDecoder,
  bytes : Bytes,
) -> Result[Bool, RaptorError] {
  match self.config.parse_packet(bytes) {
    Err(error) => Err(error)
    Ok(packet) => self.push(packet)
  }
}

///|
pub fn ObjectDecoder::block_progress(
  self : ObjectDecoder,
  index : Int32,
) -> Result[Progress, RaptorError] {
  let config = match self.config.block_config(index) {
    Err(error) => return Err(error)
    Ok(config) => config
  }
  match self.decoders[index] {
    Some(decoder) => Ok(decoder.progress())
    None =>
      Ok({
        received: self.counts[index],
        required: config.source_symbols,
        independent: if self.completed[index] is Some(_) {
          config.source_symbols
        } else {
          0
        },
      })
  }
}

///|
pub fn ObjectDecoder::decode(self : ObjectDecoder) -> Bytes? {
  if self.done != self.config.blocks {
    return None
  }
  let output = @buffer.Buffer::Buffer()
  for block in self.completed {
    output.write_bytes(block.unwrap()[:])
  }
  Some(output.to_bytes())
}
