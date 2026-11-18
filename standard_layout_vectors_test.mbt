// Generated independent Python-layout / Rust-codec vectors. Not handwritten LOC.

///|
test "independent aligned layout 0" {
  let info = @moon-raptorq.TransmissionInfo::new(53L, 12, 2, 3, 2).unwrap()
  let output = @buffer.Buffer::Buffer()
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(3, 12).unwrap()
    let packets = [
      "00000003bbc9c70e3d161bdbc2dab35d", "000000044eaccdcd564a7070de24ed68", "00000005d2697ec7bc40cfbf8baaf8d1",
      "0000000615fa8e80077de1875389eb95", "00000007b1eeb4663f206660675211ee", "00000008008ed7bc14e47c0df13ede19",
      "00000009aa08f3fef937d019e8cf7d4a", "0000000af5ad4cfdde76fab4495a389f", "0000000bca4c42ec6fb64eae0363a90b",
      "0000000c9c8322884bc452ddf114ad0a", "0000000d544bdf9e4a2cc965fd971f7b", "0000000e47d536a9c368568a88b6080e",
      "0000000f5c0cd51628edb8636d6f8117", "00000010854622c86ed7d6462f3559ad", "000000111a5661c825109d88b8c9c9b7",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(0, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(2, 12).unwrap()
    let packets = [
      "00000002c2ba9afacfa787e77f000000", "00000003fb43a592d420c6f186000000", "000000048ccaf4b61327195b0b000000",
      "0000000576b87639df864807a6000000", "0000000697d13a1a91da3111dc000000", "00000007212e341ab3fee4ca8a000000",
      "00000008333073b6c41251942c000000", "0000000987ec54814c45fd2874000000", "0000000a54e28d3c39bdd263ea000000",
      "0000000be8b20ed7233b875e8a000000", "0000000cfa35f9b09d1bd79eeb000000", "0000000d57c19267c46330c53a000000",
      "0000000e3f59f1148070d83d1d000000", "0000000f106abedf75845031be000000",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(1, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  assert_eq(
    output.to_bytes(),
    @hex.decode(
      "0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f",
    ),
  )
}

///|
test "independent aligned layout 1" {
  let info = @moon-raptorq.TransmissionInfo::new(101L, 20, 3, 7, 4).unwrap()
  let output = @buffer.Buffer::Buffer()
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(2, 20).unwrap()
    let packets = [
      "0000000290d2d2134bffdf7e563424b51c3949b801c282c2", "00000003f6136d16caa4428ca9d4c0fc2bfb5ad348792a85",
      "000000041206dcd9d27d43773fcfecc5a550425a48fff056", "00000005a33fc2a1bba56b5d852a84d2d183787bef6cf78b",
      "000000063c7e8fd6756289fe7e2630bab32018bcb8995c66", "000000079ef06ede74e6fcdda44ebe753adcbde7ea9e15bf",
      "00000008db9f6bbcfddf9c8fdf2c757cf1db468bd332b5c7", "00000009ff4a36247345fdbedaab9e501c60049bb503eafb",
      "0000000ae5cac1d216c3ac1349028ad2ff6f4bbfa0498a5f", "0000000be36e56309e219d6a171ee8559fd5b29e16a08dd0",
      "0000000c0fa7f900e1529ecccff5146bbc92d80c92187fa4", "0000000d3f05346cfaf4a759580030ad5393053ef104f166",
      "0000000e5fac354830228aa419db675dfa648be2d38972a6", "0000000fc1fe21e133904499dde9a4e0178cdc85f96ca5cf",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(0, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(2, 20).unwrap()
    let packets = [
      "00000002daaf8fefc764f5244c69d8295113132c8a3e1ec1", "0000000374e30532179353426cbce46d0fea9477335dbbb7",
      "0000000488516f2d65e3639f897c18006470aa6da40b3574", "00000005f7905e11c91fae9ee4b63437da46bb39c2dc1209",
      "00000006f1b15a7afaf5803e60f39c386b29d8c32235de83", "00000007009d87a9d035df0141a7c99391ff61367be9f31f",
      "00000008f5014287d7f20e742f054e830d49bdac2b094a79", "00000009399921f49077411ac0bc4ed169dca0b0e5d36b1d",
      "0000000a5388e7560c490797b4240efaebc4cf5818cda214", "0000000b6bfa469fe2c508a0440e476bcd4078c7b00fb3b7",
      "0000000c7cd418515273b0f63a14459114bce227fa498599", "0000000d3431629796c53a639656cbf0340e3fedf1ffac4d",
      "0000000ebc65cd28959c89d1bd23076e9467fe4dfbe94165", "0000000f0b14c0a1e56d8ad89308e4bd7d429d918f2cf8c5",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(1, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(2, 20).unwrap()
    let packets = [
      "0000000297f51b0addf8f607c07c8d9e0000000000000000", "00000003502da1c7d20261e8b1cca2a40000000000000000",
      "0000000449b958c6d32641593ee8b6270000000000000000", "00000005fc531c86a8fa2c2f96ebde040000000000000000",
      "00000006297125c7e47765c1efefb58b0000000000000000", "00000007ab4156b735d37f25e56c3c980000000000000000",
      "0000000809fa658a270db07d0587e29c0000000000000000", "000000094c3d0af38af6a73823943bb90000000000000000",
      "0000000a470c00d5f1614cb8ae05b8650000000000000000", "0000000b39301f88b1fb6f43386c3c980000000000000000",
      "0000000cd4ee333ea7898d59891ddf600000000000000000", "0000000d530bb1b95898112afa4a93d20000000000000000",
      "0000000ed210629c31af4a231825c7690000000000000000", "0000000f6155d4bcab3080d945b6ff7c0000000000000000",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(2, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  assert_eq(
    output.to_bytes(),
    @hex.decode(
      "0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f90a1b2c3d4e5f60718293a4b5c6d7e8fa0b1c2d3e4f5061728394a5b6c7d8e9fb0c1d2e3f405162738495a6b7c8d9eaf",
    ),
  )
}

///|
test "independent aligned layout 2" {
  let info = @moon-raptorq.TransmissionInfo::new(1025L, 8, 4, 2, 1).unwrap()
  let output = @buffer.Buffer::Buffer()
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(33, 8).unwrap()
    let packets = [
      "000000218fb77104720972e4", "000000224cd83e9d7cdeae41", "00000023154cabe9a9495a28",
      "0000002458d3572d7f9c84ef", "000000252b371d2e8320702a", "000000264c7808a5bf605159",
      "000000275a0a2b6003c39da9", "00000028ca215eb259df7b78", "000000293942e22e33066e6e",
      "0000002af08c4a49c8b2c2ed", "0000002b00c0906808976e11", "0000002c0372a873442667ea",
      "0000002dfd79713839da573f", "0000002e01510314bfaf160c", "0000002f0d759d37e62b30b6",
      "00000030a835bcaeab91ffeb", "0000003186c90cd10f51a96e", "00000032bd823178c53a36f7",
      "00000033383837ec97ca3c0e", "00000034ad0597cf1bb82905", "00000035399fd0ee678c0c39",
      "000000365254f78f40049aa3", "00000037d1062cbf3d712280", "000000389c28e8dd87e70f58",
      "000000391f305ba36206ab5d", "0000003a216b42261b27a114", "0000003b6d4e5e3c8b2f80c6",
      "0000003c6a3a5736a1147fff", "0000003d6000633ded0e25d5", "0000003e29a95b150b1659ac",
      "0000003f73c8ff20afe1a802", "00000040f80290a1888079aa", "0000004180d0169667230544",
      "0000004207b41f2be524f799", "00000043eeccf55c461a7825", "00000044e9e41097771dea99",
      "00000045f020e059ccf1c7e8", "0000004660eb453582507b05", "0000004764eda23c8744523f",
      "000000486a2b7537108f9606", "000000491923a0388a218a73", "0000004adb30be62e7afefa9",
      "0000004bee3be6af626e3483", "0000004ce9f2be4eadfb3815", "0000004d133558e5151b10d8",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(0, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(32, 8).unwrap()
    let packets = [
      "0000002066ddab54b3087e81", "00000021956872ef79849e03", "00000022201a41c46a500b8e",
      "000000230f16f828352cc212", "00000024985d113425e0ac89", "000000259f9c04bedbd840fa",
      "000000263bd118e316fc35ce", "00000027c762c761a005a006", "00000028eeca84cb61450b44",
      "00000029165dffe2c18a2835", "0000002aa5f8c2644f12288e", "0000002bd08892f089d1cba9",
      "0000002cc3dab9f2d9c0a3e8", "0000002dc5cfd420515b40b4", "0000002edb08ffda20f30421",
      "0000002f47c4bd58e7641df8", "00000030a756b6bdc031d1da", "000000314152a29af7e4142c",
      "0000003277fa2abee469b92d", "00000033010450d9a2a7f37a", "00000034f9e5f9c8110d1120",
      "00000035e23956cb13c8a73a", "000000364f4bebb54541e1bf", "00000037a90efbf519be4b45",
      "0000003882a3562adbfa0f73", "00000039aac468204b2589c1", "0000003a986fac617f884b86",
      "0000003bf14175893f8fbb47", "0000003cb11b6de205afd956", "0000003d8313b9ae30a00a1d",
      "0000003ee18e20b3ec832dbe", "0000003f2804e05ddef216ab", "00000040b1ce23b0c1be53c0",
      "00000041b923ef2d46dc10d2", "00000042768ccb8ecc367134", "000000437a16f616bcd030d0",
      "000000440d8ba3d31690b8c8", "00000045afe399a5fcb0caf6", "00000046524f09318499dfe7",
      "00000047de483c66ed7b0f55", "00000048325dccce6c039290", "00000049bd91ac8da38fb293",
      "0000004ae6d782caab9acf87", "0000004bf67c95a403896051",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(1, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(32, 8).unwrap()
    let packets = [
      "0000002066ddab54b3087e81", "00000021956872ef79849e03", "00000022201a41c46a500b8e",
      "000000230f16f828352cc212", "00000024985d113425e0ac89", "000000259f9c04bedbd840fa",
      "000000263bd118e316fc35ce", "00000027c762c761a005a006", "00000028eeca84cb61450b44",
      "00000029165dffe2c18a2835", "0000002aa5f8c2644f12288e", "0000002bd08892f089d1cba9",
      "0000002cc3dab9f2d9c0a3e8", "0000002dc5cfd420515b40b4", "0000002edb08ffda20f30421",
      "0000002f47c4bd58e7641df8", "00000030a756b6bdc031d1da", "000000314152a29af7e4142c",
      "0000003277fa2abee469b92d", "00000033010450d9a2a7f37a", "00000034f9e5f9c8110d1120",
      "00000035e23956cb13c8a73a", "000000364f4bebb54541e1bf", "00000037a90efbf519be4b45",
      "0000003882a3562adbfa0f73", "00000039aac468204b2589c1", "0000003a986fac617f884b86",
      "0000003bf14175893f8fbb47", "0000003cb11b6de205afd956", "0000003d8313b9ae30a00a1d",
      "0000003ee18e20b3ec832dbe", "0000003f2804e05ddef216ab", "00000040b1ce23b0c1be53c0",
      "00000041b923ef2d46dc10d2", "00000042768ccb8ecc367134", "000000437a16f616bcd030d0",
      "000000440d8ba3d31690b8c8", "00000045afe399a5fcb0caf6", "00000046524f09318499dfe7",
      "00000047de483c66ed7b0f55", "00000048325dccce6c039290", "00000049bd91ac8da38fb293",
      "0000004ae6d782caab9acf87", "0000004bf67c95a403896051",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(2, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  {
    let decoder = @moon-raptorq.StandardBlockDecoder::new(32, 8).unwrap()
    let packets = [
      "0000002066ddab54a6285020", "00000021956872ef4c918a05", "00000022201a41c41659c608",
      "000000230f16f8283334edad", "00000024985d113448626a22", "000000259f9c04be6c76964b",
      "000000263bd118e3125842b8", "00000027c762c7614b12b923", "00000028eeca84cbbd8ca6d7",
      "00000029165dffe283d26153", "0000002aa5f8c264aa36dc1f", "0000002bd08892f02969013f",
      "0000002cc3dab9f2fc14a36c", "0000002dc5cfd4209673eefe", "0000002edb08ffda717da1ab",
      "0000002f47c4bd58412a1523", "00000030a756b6bdaea4ef1f", "000000314152a29a1d3c2a13",
      "0000003277fa2abe38d8be3d", "00000033010450d98e01519e", "00000034f9e5f9c8fa155aff",
      "00000035e23956cbed117d4c", "000000364f4bebb59a09f333", "00000037a90efbf5a6d5b20d",
      "0000003882a3562a98fb267e", "00000039aac468200000303d", "0000003a986fac610725f176",
      "0000003bf1417589ed944468", "0000003cb11b6de2e14b5827", "0000003d8313b9ae1307f061",
      "0000003ee18e20b3e2aced34", "0000003f2804e05d74d21405", "00000040b1ce23b084cc8035",
      "00000041b923ef2d3cc2a011", "00000042768ccb8ef5514279", "000000437a16f616e6e7978a",
      "000000440d8ba3d3b78c8003", "00000045afe399a5cc20636e", "00000046524f0931a1ac606b",
      "00000047de483c662d793b8c", "00000048325dccced73edc62", "00000049bd91ac8d284980be",
      "0000004ae6d782ca06e8fd39", "0000004bf67c95a42341c8c0",
    ]
    for raw in packets {
      let bytes = @hex.decode(raw)
      let id = bytes[1].to_int() * 65536 +
        bytes[2].to_int() * 256 +
        bytes[3].to_int()
      decoder.push(id, bytes[4:].to_owned()).unwrap() |> ignore
    }
    output.write_bytes(
      info.reassemble_block(3, decoder.decode().unwrap().unwrap()).unwrap()[:],
    )
  }
  assert_eq(
    output.to_bytes(),
    @hex.decode(
      "0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f90a1b2c3d4e5f60718293a4b5c6d7e8fa0b1c2d3e4f5061728394a5b6c7d8e9fb0c1d2e3f405162738495a6b7c8d9eafc0d1e2f30415263748596a7b8c9daebfd0e1f2031425364758697a8b9cadbecfe0f102132435465768798a9bacbdcedff00112233445566778899aabbccddeef00112233445566778899aabbccddeeff102132435465768798a9bacbdcedfe0f2031425364758697a8b9cadbecfd0e1f30415263748596a7b8c9daebfc0d1e2f405162738495a6b7c8d9eafb0c1d2e3f5061728394a5b6c7d8e9fa0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f90a1b2c3d4e5f60718293a4b5c6d7e8fa0b1c2d3e4f5061728394a5b6c7d8e9fb0c1d2e3f405162738495a6b7c8d9eafc0d1e2f30415263748596a7b8c9daebfd0e1f2031425364758697a8b9cadbecfe0f102132435465768798a9bacbdcedff00112233445566778899aabbccddeef00112233445566778899aabbccddeeff102132435465768798a9bacbdcedfe0f2031425364758697a8b9cadbecfd0e1f30415263748596a7b8c9daebfc0d1e2f405162738495a6b7c8d9eafb0c1d2e3f5061728394a5b6c7d8e9fa0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f90a1b2c3d4e5f60718293a4b5c6d7e8fa0b1c2d3e4f5061728394a5b6c7d8e9fb0c1d2e3f405162738495a6b7c8d9eafc0d1e2f30415263748596a7b8c9daebfd0e1f2031425364758697a8b9cadbecfe0f102132435465768798a9bacbdcedff00112233445566778899aabbccddeef00112233445566778899aabbccddeeff102132435465768798a9bacbdcedfe0f2031425364758697a8b9cadbecfd0e1f30415263748596a7b8c9daebfc0d1e2f405162738495a6b7c8d9eafb0c1d2e3f5061728394a5b6c7d8e9fa0b1c2d3e4f60718293a4b5c6d7e8f90a1b2c3d4e5f708192a3b4c5d6e7f8091a2b3c4d5e6f8091a2b3c4d5e6f708192a3b4c5d6e7f90a1b2c3d4e5f60718293a4b5c6d7e8fa0b1c2d3e4f5061728394a5b6c7d8e9fb0c1d2e3f405162738495a6b7c8d9eafc0d1e2f30415263748596a7b8c9daebfd0e1f2031425364758697a8b9cadbecfe0f102132435465768798a9bacbdcedff00112233445566778899aabbccddeef00112233445566778899aabbccddeeff102132435465768798a9bacbdcedfe0f2031425364758697a8b9cadbecfd0e1f30415263748596a7b8c9daebfc0d1e2f405162738495a6b7c8d9eafb0c1d2e3f5061728394a5b6c7d8e9fa0b",
    ),
  )
}
