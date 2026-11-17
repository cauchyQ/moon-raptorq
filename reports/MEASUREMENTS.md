# 实际对照测量

以下内容由 tools/benchmark.py 从原始测量自动汇总，单位为毫秒。

| 后端 | 场景 | 实际库 | 恢复成功 | 编码中位数 | 解码中位数 | 发送字节 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| js | edge-handoff | MoonErasure-0.3.0 | 5/5 | 11.408 | 12.867 | 10784 |
| js | edge-handoff | MoonRaptorQ-batch | 5/5 | 4.263 | 4.676 | 7628 |
| js | edge-handoff | MoonRaptorQ-stream | 5/5 | 4.235 | 4.233 | 7628 |
| js | edge-handoff | MoonRecoder-0.1.1 | 5/5 | 8.402 | 10.326 | 17472 |
| js | intermittent-device | MoonErasure-0.3.0 | 5/5 | 13.516 | 16.998 | 17952 |
| js | intermittent-device | MoonRaptorQ-batch | 5/5 | 8.726 | 9.289 | 14796 |
| js | intermittent-device | MoonRaptorQ-stream | 5/5 | 6.875 | 6.983 | 14796 |
| js | intermittent-device | MoonRecoder-0.1.1 | 2/5 | 15.674 | 19.924 | 24640 |
| js | multicast | MoonErasure-0.3.0 | 30/30 | 2.979 | 3.390 | 10272 |
| js | multicast | MoonRaptorQ-batch | 30/30 | 2.376 | 3.042 | 8460 |
| js | multicast | MoonRaptorQ-stream | 30/30 | 2.427 | 2.548 | 8460 |
| js | multicast | MoonRecoder-0.1.1 | 30/30 | 5.375 | 5.308 | 12032 |
| wasm | edge-handoff | MoonErasure-0.3.0 | 5/5 | 18.710 | 21.397 | 10784 |
| wasm | edge-handoff | MoonRaptorQ-batch | 5/5 | 3.601 | 4.322 | 7628 |
| wasm | edge-handoff | MoonRaptorQ-stream | 5/5 | 3.673 | 4.092 | 7628 |
| wasm | edge-handoff | MoonRecoder-0.1.1 | 5/5 | 12.574 | 11.541 | 17472 |
| wasm | intermittent-device | MoonErasure-0.3.0 | 5/5 | 24.773 | 30.389 | 17952 |
| wasm | intermittent-device | MoonRaptorQ-batch | 5/5 | 5.882 | 6.844 | 14796 |
| wasm | intermittent-device | MoonRaptorQ-stream | 5/5 | 6.219 | 6.633 | 14796 |
| wasm | intermittent-device | MoonRecoder-0.1.1 | 2/5 | 24.161 | 26.273 | 24640 |
| wasm | multicast | MoonErasure-0.3.0 | 30/30 | 4.031 | 4.741 | 10272 |
| wasm | multicast | MoonRaptorQ-batch | 30/30 | 2.136 | 2.699 | 8460 |
| wasm | multicast | MoonRaptorQ-stream | 30/30 | 2.255 | 2.769 | 8460 |
| wasm | multicast | MoonRecoder-0.1.1 | 30/30 | 7.955 | 7.151 | 12032 |

原始数据包含预热行（repetition=-1），统计时剔除；每组五轮。组播编码一次供六个接收方使用。
时间包含实际报文生成/解析，各协议的校验、元数据与保护能力不同，不能把字节差直接解释为同等安全保证下的压缩收益。
MoonErasure 接收适配器先去重，去重耗时及重复报文字节均计入。此实验没有模拟完整网络协议、重传反馈、带宽竞争或真实设备。
