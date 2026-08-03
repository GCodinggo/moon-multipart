# 2026年8月 MoonBit 黑客松 — moon-multipart 项目申报书

## 基本信息

| 项目名称 | moon-multipart |
|---|---|
| 项目类型 | 原创 MoonBit 开源生态库 |
| 参赛者 | 郭康泰 |
| GitHub | https://github.com/GCodinggo/moon-multipart |
| Mooncakes | 待发布（GCodinggo/moon-multipart） |
| 当前版本 | v0.3.0 |
| 许可证 | Apache-2.0 |
| 联系方式 | 通过官方报名问卷单独提交 |

## 项目背景

multipart/form-data 是浏览器文件上传和 HTTP API 表单提交中广泛使用的编码格式。
moon-multipart 为 MoonBit 提供流式 multipart/form-data 解析与生成能力，
支持跨网络分块的 boundary 检测、安全限制、文件名校验和请求头注入防护。

## 当前基础

- 8 个主要源码模块
- 96 个测试用例
- 流式 Parser 和 MultipartWriter
- StreamingWriter 分块写入接口
- Strict / Compatible 双解析模式
- 同名字段与多文件高层 API
- CRLF 请求头注入防护
- Windows 文件名和路径安全规则
- GitHub Actions 多目标验证配置

## 本次活动计划

### v0.4.0

- HTTP 上传服务端和客户端示例
- curl / Python / Go / Node.js 跨语言兼容测试
- 属性测试和随机分块一致性测试
- 大文件和不同分块尺寸性能测试
- 完善 API 文档和使用示例

## 技术路线

解析器采用增量字节流状态机，在网络分块输入下识别 multipart boundary，
通过 ParseEvent 输出 PartBegin、PartData、PartEnd 和 Finished 事件。
调用方可将文件数据直接写入存储或计算哈希。

Writer 侧在序列化前校验字段名、文件名、Content-Type 和自定义请求头，
阻止 CRLF 注入，并提供安全文件名验证和清理接口。

## 预计交付

- 可公开安装的 MoonBit 库
- HTTP 文件上传客户端和服务端示例
- 跨语言兼容测试
- 属性测试和性能基准
- 完整 README、API 文档和 CHANGELOG
- GitHub Actions 持续集成
