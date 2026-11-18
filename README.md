# MoonRaptorQ

面向丢包环境对象分发的纯 MoonBit RaptorQ 库。实现 RFC 6330 的系统式编码、LDPC/HDPC 预编码和 GF(256) 恢复，支持按需生成修复符号。

项目定位、三个使用场景和交付范围见[项目申报书](moon-raptorq-项目申报书.md)。

本轮按 2026-11-18 审核邮件整改，最终目标改为完整 RFC 6330 符合性。新增完整参数模型、稀疏失活编解码、子块交织和多符号包接口；完整符合性尚需补齐全表恢复性质及更多独立互操作证据。详见 [整改与符合性矩阵](docs/RFC6330-整改与符合性.md)。

新增路径：`TransmissionInfo` 验证完整 OTI；`StandardBlockEncoder` / `StandardBlockDecoder` 支持 K=1..56403、T=1..65535，执行预算通过 `ExecutionLimits` 配置；`EncodingPacket` 支持聚合符号。大型对象逐块处理，使用 Int64 布局偏移。运行 `moon run examples/standard --release` 查看 Al=2、N=3、多源块、聚合修复包的示例；运行 `python tools/verify_standard.py` 复核最大 K 及 Rust 双向交换。

| 新标准路径 | 范围与执行条件 |
| --- | --- |
| 源块参数 | K=1～56,403，完整 477 行参数表 |
| OTI | T=1～65,535；Z=1～255；N=1～65,535；Al=1～255；校验对齐及每块 K 上限 |
| 对象长度 | Int64 表示，最大 942,574,504,275 字节；按源块交给调用者读写 |
| 布局及报文 | 对齐的子块交织、尾部补零、连续多符号包、源块路由 |
| 执行预算 | `ExecutionLimits` 可调；最大 K 的修复恢复验证使用 33,554,432 项稀疏系数预算 |

下表及原有 `Config`、`Encoder`、`StreamDecoder`、`ObjectConfig` 接口仍描述 **0.1.0 兼容的小规模路径**。本轮源码准备为 0.2.0；Mooncakes 最新发布仍为 0.1.0，不能用旧发布包验证本轮功能。

## 支持范围

| 项目 | 当前支持 |
| --- | --- |
| 单源块 | K=1～256，符号大小 T=1～4096 字节 |
| 多源块对象 | Z=1～16，每块 K≤256，总对象最多 16 MiB |
| 子块与对齐 | N=1、Al=1；不支持子块交织 |
| 标准报文 | 12 字节 OTI；1 字节源块号、3 字节 ESI、一个 T 字节符号 |
| 编码符号 ID | 0～16,777,215；源符号与修复符号正确映射到内部 ISI |
| 接收上限 | 每块保留 K+64 个不同 ESI；重复包不占额外名额 |
| 后端 | Wasm、Wasm GC、JavaScript |

`Encoder` 直接建立中间符号；`EncodingPlan` 允许复用同一 K 的编码变换。`Decoder` 提供批量恢复，`StreamDecoder` 每包更新一次方程基础，并公开独立秩和剩余自由度。`ObjectDecoder` 完成一个块后释放其消元矩阵，通过活跃块预算限制内存。`PacketFramer` 和 `ObjectFramer` 接受任意字节分片，遇到错误时整次输入回滚。

单块接收器支持检查点：保存已收标准符号、OTI 和 CRC32C，重启后可恢复成批量或流式接收器。外层检查点是本项目自己的存储格式，不是 RFC 网络报文，也不提供真实性验证。

**收到 K 个不同符号不等于一定能恢复。** 应检查解码结果或独立秩，必要时继续接收修复符号。RaptorQ 处理擦除，不提供对象身份、密码学完整性或真实性。恢复结果进入真实固件、配置或资源系统前，应由上层验证对象摘要和签名。

## 运行

本次验证使用 MoonBit v0.10.19、moon 0.1.20261102。先执行：

```powershell
moon update
moon check --deny-warn
moon test --release --deny-warn
moon run examples/multicast --release
moon run examples/device --release
moon run examples/edge --release --target js
moon run examples/object --release
moon run examples/resume --release
moon run examples/standard --release
```

前三个示例分别模拟多接收方资源分发、设备传输中断和边缘对象交接；其余演示多源块内存释放、检查点续传及新标准接口的子块和聚合包。它们都是离线模拟，没有声称已经接入真实设备或浏览器页面。

CLI 接受十六进制字节，适合检查报文和小规模联调：

```powershell
moon run cmd/main --release -- encode 4 0102030405060708 2 12
moon run cmd/main --release -- estimate 1048576 4096
moon run cmd/main --release -- --help
```

第一条输出 OTI 和修复包。将 OTI 与若干包的十六进制内容依次传给 `decode OTI_HEX PACKET_HEX ...` 即可恢复；方程不足时输出 waiting。大文件应使用库 API，避免命令行参数长度限制。

`save OTI_HEX PACKET_HEX ...` 输出检查点；`resume CHECKPOINT_HEX PACKET_HEX ...` 加载检查点后继续收包。未完成时会输出更新的检查点和 waiting，完成后输出原始数据。

在其他 MoonBit 包中，通过 `moon.pkg` 导入本模块并取别名 `rq`：

```moonbit
let source = b"MoonBit object distribution"
let encoder = @rq.Encoder::new(source, 4).unwrap()
let receiver = @rq.StreamDecoder::new(encoder.config())
let k = encoder.config().source_symbols()
for id in k..<(2 * k + 8) {
  ignore(receiver.push_bytes(encoder.packet(id).unwrap().serialize()).unwrap())
}
assert_eq(receiver.decode().unwrap(), Some(source))
```

源码仓库：[cauchyQ/moon-raptorq](https://github.com/cauchyQ/moon-raptorq)。发布版本为 `cauchyQ/moon-raptorq@0.1.0`，在消费项目中执行 `moon add cauchyQ/moon-raptorq@0.1.0` 安装，然后在 `moon.pkg` 导入并取别名 `rq`。

## 独立验证与对照

核心库只调用 MoonBit 标准库；模块中的 MoonErasure 和 MoonRecoder 依赖用于对照实验，没有参与本库编解码。独立参考是 Rust `raptorq==2.0.0`，Python 仅负责调用其编译后的实现。

Linux 下安装参考库并运行：

```sh
python -m pip install --target .verification/reference-python2 raptorq==2.0.0
python tools/verify_interop.py
python tools/verify_standard.py
python tools/verify_layout.py
python tools/benchmark.py
python tools/scaling.py
python tools/check.py
python tools/source_lines.py
```

Windows 上，互操作脚本通过 WSL 调用 Linux Python。将参考库安装到同一个 `.verification/reference-python2` 目录即可；普通 MoonBit 测试和示例不依赖 WSL。

- [实测对照表](reports/MEASUREMENTS.md)：相同对象、符号大小、包数预算和丢包轨迹，运行实际发布的 MoonErasure、MoonRecoder 和本库。
- [规模与修复开销](reports/SCALING.md)：K=16/64/128/256、不同符号大小、计划建立与复用分别计时。
- [算法改进实测](reports/OPTIMIZATION.md)：完整源符号直接恢复、XOR 与单位主元优化的前后数据。
- [互操作结果](reports/interop.json)：12 组单块参数双向恢复及逐字节比较；另有 2 组多块划分测试。
- [标准范围验证报告](reports/RFC6330-验证报告.md)：新增大块、完整字段和子块布局证据；原始数据见 [大块双向验证](reports/standard-interop.json)、[子块布局双向验证](reports/layout-interop.json)。
- [设计与范围](docs/DESIGN.md)、[比较方法和解读](docs/COMPARISON.md)、[交付记录](docs/DELIVERY.md)。

多块验证由独立 Python 划分对象，再逐块调用 Rust 编解码器，并检查完整对象重组。Rust Python 接口没有自定义多块 OTI 入口，因此没有把它写成 Rust 完整多块接口的端到端验证。

## 来源和许可证

Apache-2.0，见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。标准常量和 HDPC 递推参考 `cberner/raptorq` 的固定版本；归属和修改范围已记录。固定常量、自动生成的参考向量与手写代码分开统计，见 [代码统计](reports/source-lines.json)。

项目以完整 RFC 6330 符合性为最终目标，当前测试仍不足以证明第 5.8 节全表恢复性质。正式提交时应核对标准覆盖矩阵、发布版本、远程 CI 和申报材料，后续开发记录应持续、真实地积累。
