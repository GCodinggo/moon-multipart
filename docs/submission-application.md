# 2026年8月 MoonBit 黑客松 — moon-multipart 项目申报书

## 基本信息

| 项目名称 | moon-multipart | 类型 | 原创 MoonBit 开源生态库 |
|----------|---------------|------|------------------------|
| **参赛者** | 郭康泰 | **联系方式** | 已通过官方报名问卷提交 |
| **许可证** | Apache-2.0 | | |
| **GitHub** | github.com/GCodinggo/moon-multipart | **Mooncakes** | GCodinggo/moon-multipart |

## 仓库与提交身份说明

本项目参赛者及主要维护者为郭康泰。

项目早期部分提交由于开发电脑中的 Git 作者姓名和邮箱配置错误，
在 GitHub Contributors 和 Commit 页面中显示为其他身份。
该问题属于 Git 提交元数据配置错误，不代表项目仓库所有权发生变化。

目前已完成以下修正：

1. GitHub 公开资料已更新为郭康泰本人信息；
2. 当前仓库已使用郭康泰本人的 Git 姓名；
3. 当前仓库已使用郭康泰本人 GitHub 已验证邮箱；
4. 后续版本均由郭康泰本人持续开发并提交；
5. 原历史记录暂不重写，以保留完整开发轨迹。

## 项目背景

multipart/form-data（RFC 7578）是浏览器上传文件、REST API 提交表单的标准编码格式。MoonBit 已具备 HTTP/异步 I/O 等基础能力（`moonbitlang/async`），但缺少成熟的 multipart 解析与生成库。moon-multipart 补齐这一空白，使 MoonBit HTTP 服务能够正确接收文件上传、处理跨网络分块的 boundary 识别、对大文件进行增量流式处理，并提供上传文件名的安全清理。

## 当前版本（v0.3.0）

| 维度 | 内容 |
|------|------|
| **源码** | 8 个模块（model / parser / content_type / boundary_matcher / writer / streaming_writer / safe_filename），含测试约 4,900 行 |
| **测试** | 96 个用例全部通过，覆盖 boundary 解析、端到端 roundtrip、跨分块流式、安全限制、CRLF 注入防护、Windows 文件名规则和双模式 |
| **核心功能** | 增量流式 Parser（PartData 逐块输出，不缓存文件）；独立 boundary 匹配器；高层 MultipartForm API（同名字段/多文件）；Strict / Compatible 双模式；6 维度安全限制；安全文件名（路径穿越、Windows 保留设备名、尾随空格与点号防护）；Writer 请求头 CRLF 防护；StreamingWriter 分段写入；cmd/main 本地 roundtrip demo |
| **CI** | GitHub Actions 多目标矩阵（native / js / wasm-gc） |
| **发布** | 已上架 Mooncakes (`GCodinggo/moon-multipart`) |

## 本次活动已完成（v0.3.0）

**v0.3.0 — 安全加固：** 增加 Writer 请求头 CRLF 注入防护和可返回错误的校验 API；补充 Windows 保留设备名、盘符／UNC 路径、尾随空格与点号的文件名安全规则；新增对应回归测试。

## 后续计划（v0.4.0）

**v0.4.0 — 生态集成与兼容性验证：** HTTP 上传服务端/客户端示例；curl / Python / Go / Node.js 跨语言兼容测试；性能基准测试；属性测试。

## 技术路线

核心采用增量字节流状态机实现解析，独立 boundary 匹配器避免文件内容中出现 `--boundary` 时的误判。低层 API 以 `ParseEvent` 输出事件，调用方可直接将数据写入文件或网络；高层 API 将事件聚合为 `MultipartForm`。Writer 侧支持分段提供数据，并在序列化前校验所有请求头参数。

## 预计交付

可发布的 MoonBit 库（v0.3.0）；完整 README 与 API 文档；96 个回归测试；后续将补充 HTTP 上传服务端/客户端示例、属性测试、跨语言兼容测试与 Benchmark 结果。
