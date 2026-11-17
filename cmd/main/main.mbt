///|
fn usage() -> Unit {
  println("MoonRaptorQ bounded RFC 6330 CLI")
  println("encode T DATA_HEX FIRST_ESI COUNT")
  println("decode OTI_HEX PACKET_HEX ...")
  println("estimate LENGTH T")
  println("save OTI_HEX PACKET_HEX ...")
  println("resume CHECKPOINT_HEX PACKET_HEX ...")
  println("Profile: Z=N=Al=1, K<=256, T<=4096, one symbol per packet.")
}

///|
fn failed(message : String) -> Unit {
  println("error: " + message)
  @env.exit(2)
}

///|
fn number(value : String) -> Int32 {
  @string.parse_int(value) catch {
    _ => {
      failed("expected a decimal integer")
      0
    }
  }
}

///|
fn bytes(value : String) -> Bytes {
  @hex.decode(value) catch {
    _ => {
      failed("expected even-length hexadecimal bytes")
      b""
    }
  }
}

///|
fn main {
  let arguments = @env.args()
  let mut start = 0
  while start < arguments.length() {
    if arguments[start] == "save" ||
      arguments[start] == "resume" ||
      arguments[start] == "encode" ||
      arguments[start] == "decode" ||
      arguments[start] == "estimate" ||
      arguments[start] == "--help" {
      break
    }
    start += 1
  }
  if start == arguments.length() {
    usage()
    @env.exit(2)
  }
  let args = arguments[start:]
  match args[0] {
    "save" => {
      if args.length() < 2 || args.length() > 322 {
        usage()
        @env.exit(2)
      }
      let config = match @rq.parse_config(bytes(args[1])) {
        Ok(config) => config
        Err(error) => {
          failed(error.message())
          return
        }
      }
      let decoder = @rq.StreamDecoder::new(config)
      for index in 2..<args.length() {
        match decoder.push_bytes(bytes(args[index])) {
          Ok(_) => ()
          Err(error) => {
            failed(error.message())
            return
          }
        }
      }
      println("checkpoint " + @hex.encode(decoder.checkpoint()[:]))
    }
    "resume" => {
      if args.length() < 2 || args.length() > 322 {
        usage()
        @env.exit(2)
      }
      let decoder = match @rq.restore_stream_decoder(bytes(args[1])) {
        Ok(decoder) => decoder
        Err(error) => {
          failed(error.message())
          return
        }
      }
      for index in 2..<args.length() {
        match decoder.push_bytes(bytes(args[index])) {
          Ok(_) => ()
          Err(error) => {
            failed(error.message())
            return
          }
        }
      }
      match decoder.decode() {
        Err(error) => failed(error.message())
        Ok(Some(data)) => println("data " + @hex.encode(data[:]))
        Ok(None) => {
          println("checkpoint " + @hex.encode(decoder.checkpoint()[:]))
          println(
            "waiting: \{decoder.progress().remaining()} independent equations missing",
          )
          @env.exit(3)
        }
      }
    }
    "--help" => usage()
    "estimate" => {
      if args.length() != 3 {
        usage()
        @env.exit(2)
      }
      let config = match @rq.Config::new(number(args[1]), number(args[2])) {
        Ok(config) => config
        Err(error) => {
          failed(error.message())
          return
        }
      }
      let storage = config.stream_storage()
      println(
        "{\"K\":\{config.source_symbols()},\"raw_storage_bytes\":\{storage.raw_total()},\"includes_runtime_overhead\":false}",
      )
    }
    "encode" => {
      if args.length() != 5 {
        usage()
        @env.exit(2)
      }
      let size = number(args[1])
      let data = bytes(args[2])
      let first = number(args[3])
      let count = number(args[4])
      if first < 0 ||
        first >= 16777216 ||
        count < 1 ||
        count > 320 ||
        count > 16777216 - first {
        failed("ESI range outside 24 bits or count outside 1..320")
        return
      }
      let encoder = match @rq.Encoder::new(data, size) {
        Ok(encoder) => encoder
        Err(error) => {
          failed(error.message())
          return
        }
      }
      println("oti " + @hex.encode(encoder.config().serialize()[:]))
      for id in first..<(first + count) {
        println(
          "packet " + @hex.encode(encoder.packet(id).unwrap().serialize()[:]),
        )
      }
    }
    "decode" => {
      if args.length() < 3 || args.length() > 322 {
        usage()
        @env.exit(2)
      }
      let config = match @rq.parse_config(bytes(args[1])) {
        Ok(config) => config
        Err(error) => {
          failed(error.message())
          return
        }
      }
      let decoder = @rq.StreamDecoder::new(config)
      for i in 2..<args.length() {
        match decoder.push_bytes(bytes(args[i])) {
          Ok(_) => ()
          Err(error) => {
            failed(error.message())
            return
          }
        }
      }
      match decoder.decode() {
        Err(error) => failed(error.message())
        Ok(Some(data)) => println("data " + @hex.encode(data[:]))
        Ok(None) => {
          println(
            "waiting: \{decoder.progress().remaining()} independent equations missing",
          )
          @env.exit(3)
        }
      }
    }
    _ => {
      usage()
      @env.exit(2)
    }
  }
}
