# 实际对照测量

以下内容由 tools/benchmark.py 从原始测量自动汇总，单位为毫秒。

| 后端 | 场景 | 实际库 | 恢复成功 | 编码中位数 | 解码中位数 | 发送字节 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| js | edge-handoff | MoonErasure-0.3.0 | 5/5 | 11.322 | 13.341 | 10784 |
| js | edge-handoff | MoonRaptorQ-batch | 5/5 | 5.280 | 6.547 | 7628 |
| js | edge-handoff | MoonRaptorQ-stream | 5/5 | 5.455 | 8.350 | 7628 |
| js | edge-handoff | MoonRecoder-0.1.1 | 5/5 | 8.110 | 9.626 | 17472 |
| js | intermittent-device | MoonErasure-0.3.0 | 5/5 | 13.387 | 17.134 | 17952 |
| js | intermittent-device | MoonRaptorQ-batch | 5/5 | 8.910 | 10.334 | 14796 |
| js | intermittent-device | MoonRaptorQ-stream | 5/5 | 9.497 | 11.114 | 14796 |
| js | intermittent-device | MoonRecoder-0.1.1 | 2/5 | 15.448 | 19.512 | 24640 |
| js | multicast | MoonErasure-0.3.0 | 30/30 | 3.107 | 3.389 | 10272 |
| js | multicast | MoonRaptorQ-batch | 30/30 | 3.242 | 4.010 | 8460 |
| js | multicast | MoonRaptorQ-stream | 30/30 | 3.326 | 4.121 | 8460 |
| js | multicast | MoonRecoder-0.1.1 | 30/30 | 5.281 | 5.087 | 12032 |
| wasm | edge-handoff | MoonErasure-0.3.0 | 5/5 | 18.356 | 21.070 | 10784 |
| wasm | edge-handoff | MoonRaptorQ-batch | 5/5 | 5.154 | 6.085 | 7628 |
| wasm | edge-handoff | MoonRaptorQ-stream | 5/5 | 5.192 | 5.990 | 7628 |
| wasm | edge-handoff | MoonRecoder-0.1.1 | 5/5 | 12.342 | 10.961 | 17472 |
| wasm | intermittent-device | MoonErasure-0.3.0 | 5/5 | 20.735 | 28.304 | 17952 |
| wasm | intermittent-device | MoonRaptorQ-batch | 5/5 | 8.758 | 9.996 | 14796 |
| wasm | intermittent-device | MoonRaptorQ-stream | 5/5 | 8.851 | 9.699 | 14796 |
| wasm | intermittent-device | MoonRecoder-0.1.1 | 2/5 | 24.187 | 26.443 | 24640 |
| wasm | multicast | MoonErasure-0.3.0 | 30/30 | 4.214 | 4.541 | 10272 |
| wasm | multicast | MoonRaptorQ-batch | 30/30 | 3.104 | 3.980 | 8460 |
| wasm | multicast | MoonRaptorQ-stream | 30/30 | 3.221 | 3.831 | 8460 |
| wasm | multicast | MoonRecoder-0.1.1 | 30/30 | 7.904 | 6.945 | 12032 |

原始数据包含预热行（repetition=-1），统计时剔除；每组五轮。组播编码一次供六个接收方使用。
时间包含实际报文生成/解析，各协议的校验、元数据与保护能力不同，不能把字节差直接解释为同等安全保证下的压缩收益。
MoonErasure 接收适配器先去重，去重耗时及重复报文字节均计入。此实验没有模拟完整网络协议、重传反馈、带宽竞争或真实设备。
