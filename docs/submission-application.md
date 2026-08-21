# 2026年8月 MoonBit 黑客松 — moon-multipart 项目申报书

## 基本信息

| 项目名称 | moon-multipart |
|---|---|
| 项目类型 | 原创 MoonBit 开源生态库 |
| 参赛者 | 郭康泰 |
| GitHub | https://github.com/GCodinggo/moon-multipart |
| Mooncakes | GCodinggo/moon-multipart |
| 当前版本 | v0.3.2 |
| 许可证 | Apache-2.0 |
| 联系方式 | 通过官方报名问卷单独提交 |

## 项目背景

multipart/form-data 是浏览器文件上传和 HTTP API 表单提交中广泛使用的编码格式。
moon-multipart 为 MoonBit 提供流式 multipart/form-data 解析与生成能力，
支持跨网络分块的 boundary 检测、安全限制、文件名校验和请求头注入防护。

## 最终交付

- 8 个主要源码模块
- 3,246 行有效 MoonBit 代码（含测试和 CLI）
- 96 个测试用例在 native、JavaScript、wasm、wasm-gc 四个目标全部通过
- 流式 Parser 和 MultipartWriter
- StreamingWriter 分块写入接口
- Strict / Compatible 双解析模式
- 同名字段与多文件高层 API
- CRLF 请求头注入防护
- Windows 文件名和路径安全规则
- GitHub Actions 四目标严格验证配置

## 本次活动完成内容与范围调整

- 将基础解析器扩展为完整的流式 Parser、MultipartWriter、StreamingWriter 和高层 MultipartForm API
- 增加 Strict / Compatible 双模式、跨分块 boundary 检测、同名字段与多文件支持
- 增加 CRLF 注入、路径穿越、Windows 保留名称、资源上限和危险文件名防护
- 完成 96 项自动化测试、四目标严格 CI、CLI 往返示例、README、贡献指南和更新日志
- 为保持库的跨目标可移植性和 HTTP 框架中立，服务端、客户端和网络性能测试由调用方集成层负责，不纳入核心包

## 技术路线

解析器采用增量字节流状态机，在网络分块输入下识别 multipart boundary，
通过 ParseEvent 输出 PartBegin、PartData、PartEnd 和 Finished 事件。
调用方可将文件数据直接写入存储或计算哈希。

Writer 侧在序列化前校验字段名、文件名、Content-Type 和自定义请求头，
阻止 CRLF 注入，并提供安全文件名验证和清理接口。

## 已完成交付

- 可公开安装的 MoonBit 库
- 可运行的 multipart 生成与解析往返示例
- 96 项覆盖解析、生成、跨分块、安全限制和异常输入的测试
- 完整 README、API 文档和 CHANGELOG
- GitHub Actions 四目标持续集成
