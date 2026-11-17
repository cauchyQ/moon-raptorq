// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "cauchyQ/moon-raptorq"

version = "0.1.0"

readme = "README.md"

repository = ""

license = "Apache-2.0"

keywords = [ "raptorq", "fec", "rfc6330", "erasure-coding" ]

preferred_target = "wasm"

description = "Bounded pure MoonBit RFC 6330 RaptorQ with incremental decoding and interoperability checks"

import {
  "oyjh0381/moonerasure@0.3.0",
  "ZJH-666-ZJH/moonrecoder@0.1.1",
}
