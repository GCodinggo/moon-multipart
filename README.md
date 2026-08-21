# moon-multipart

面向 MoonBit HTTP 生态的**流式 multipart/form-data 解析与生成库**，完整实现 RFC 7578 标准。

## 项目维护者

本项目由郭康泰开发和维护。

GitHub 用户名为 `GCodinggo`。

## 特性

- **RFC 7578 合规** — 完整支持 multipart/form-data 编码格式
- **流式解析** — 增量处理上传数据，PartData 逐块输出，不将整个文件加载到内存
- **跨分块边界检测** — 正确处理被网络分块拆分的 boundary 分隔符
- **安全限制** — 6 维度可配置限制（part 数量、header 大小、字段大小、文件大小、总大小、文件名长度）
- **请求头注入防护** — 拒绝字段名、文件名、Content-Type 和自定义 header 中的 CRLF
- **路径穿越防护** — 检测并拒绝 `../`、`\`、盘符、UNC 路径、Windows 保留设备名、尾随空格或点号、null 字节等危险文件名
- **安全文件名工具** — `safe_filename()`、`validate_filename()`、`unique_filename()`
- **严格/兼容双模式** — Strict 模式拒绝非标准扩展（如 `filename*`），Compatible 模式宽松接受
- **流式 Writer** — `StreamingWriter` 支持 `begin_part` / `write_chunk` / `end_part` 分块添加数据，并提供带校验的 `try_begin_part`
- **高层 API** — `parse_all()` 一键解析返回 `MultipartForm`，支持同名字段/多文件

## 快速开始

### 安装

```bash
moon add GCodinggo/moon-multipart
```

### 解析 multipart 请求体（高层 API）

```mbt
let content_type = "multipart/form-data; boundary=----WebKitFormBoundary"
let boundary = parse_boundary_from_content_type(content_type)?
let form = parse_all(body, boundary, ParseOptions::default())?
// 读取字段
let username = form.field("username")
// 读取同名多值
let tags = form.field_values("tag")
// 读取文件
match form.file("avatar") {
  Some(part) => { let data = part.data(); let fname = part.filename() }
  None => { }
}
// 读取同名多文件
let images = form.files("image")
```

### 解析 multipart 请求体（流式低层 API）

```mbt
let boundary = parse_boundary_from_content_type(content_type)?
let parser = Parser::new(boundary, ParseOptions::default())
for chunk in incoming_chunks {
  let events = parser.feed(chunk)?
  for event in events {
    match event {
      PartBegin(name, filename, content_type) => { /* 新 part 开始 */ }
      PartData(data) => { /* body 数据块，直接写文件/哈希 */ }
      PartEnd => { /* part 结束 */ }
      Finished => { /* 解析完成 */ }
    }
  }
}
parser.finish()?
```

### 生成 multipart 请求体（基础 API）

```mbt
let writer = MultipartWriter::new()
writer.add_field("username", "alice")
writer.add_file("avatar", "photo.png", Some("image/png"), image_bytes)
let (boundary, body) = writer.finish()
// Content-Type: multipart/form-data; boundary=<boundary>
```

### 生成 multipart 请求体（流式 API）

```mbt
let sw = StreamingWriter::new(boundary)
sw.begin_part("file", Some("large.bin"), Some("application/octet-stream"))
for chunk in read_file_in_chunks("large.bin") {
  sw.write_chunk(chunk)
}
sw.end_part()
let body = sw.finish()
```

### 安全文件名处理

```mbt
// 验证
validate_filename("photo.jpg", 255)?

// 清理危险字符
let safe = safe_filename("../../../etc/passwd")  // → "______etc_passwd"

// 生成唯一名称
let unique = unique_filename("photo.jpg")  // → "photo_3A7F2C1D.jpg"
```

## API 参考

### 类型

| 类型 | 说明 |
|------|------|
| `Limits` | 安全限制配置，提供 `default()` / `strict()` / `permissive()` |
| `ParseMode` | `Strict` / `Compatible` |
| `ParseOptions` | 解析选项：mode + limits + reject_filename_star |
| `Part` | 解析后的 part：`Field(String, String)` / `File(String, String, String?, Bytes)` |
| `MultipartForm` | 高层解析结果，有序 parts，支持 `field()` / `field_values()` / `file()` / `files()` |
| `MultipartError` | 16 种错误类型 |
| `ParseEvent` | 流式事件：`PartBegin` / `PartData` / `PartEnd` / `Finished` |
| `Parser` | 流式解析器 |
| `MultipartWriter` | 基础请求体生成器 |
| `StreamingWriter` | 流式请求体生成器（begin_part / write_chunk / end_part） |

### 核心函数

**Content-Type 解析**

- `parse_boundary_from_content_type(content_type) -> Result[String, MultipartError]`
- `validate_boundary(boundary) -> Result[String, MultipartError]`

**Content-Disposition 解析**

- `parse_content_disposition(header, ParseOptions) -> Result[(String, String?), MultipartError]`
- `parse_header_line(line) -> (String, String)?`

**Parser**

- `Parser::new(boundary, ParseOptions) -> Parser`
- `Parser::feed(self, chunk) -> Result[Array[ParseEvent], MultipartError]`
- `Parser::finish(self) -> Result[Array[ParseEvent], MultipartError]`
- `parse_all(body, boundary, ParseOptions) -> Result[MultipartForm, MultipartError]`

**MultipartWriter**

- `MultipartWriter::new() -> MultipartWriter`
- `MultipartWriter::with_boundary(boundary) -> MultipartWriter`
- `MultipartWriter::add_field(self, name, value) -> Unit`
- `MultipartWriter::add_file(self, name, filename, content_type?, data) -> Unit`
- `MultipartWriter::try_add_field(self, name, value) -> Result[Unit, MultipartError]`
- `MultipartWriter::try_add_file(self, name, filename, content_type?, data) -> Result[Unit, MultipartError]`
- `MultipartWriter::try_add_file_with_headers(self, name, filename, content_type?, extra_headers, data) -> Result[Unit, MultipartError]`
- `MultipartWriter::finish(self) -> (String, Bytes)`

**StreamingWriter**

- `StreamingWriter::new(boundary) -> StreamingWriter`
- `StreamingWriter::begin_part(self, name, filename?, content_type?) -> Unit`
- `StreamingWriter::try_begin_part(self, name, filename?, content_type?) -> Result[Unit, MultipartError]`
- `StreamingWriter::write_chunk(self, data) -> Unit`
- `StreamingWriter::end_part(self) -> Unit`
- `StreamingWriter::finish(self) -> Bytes`

**安全文件名**

- `is_dangerous_filename(filename) -> Bool`
- `validate_filename(filename, max_len) -> Result[String, MultipartError]`
- `safe_filename(original) -> String`
- `unique_filename(original) -> String`
- `validate_header_component(value, label) -> Result[Unit, MultipartError]`
- `validate_custom_header(name, value) -> Result[Unit, MultipartError]`

## 安全限制

| 限制 | 默认值 | strict() |
|------|--------|----------|
| 最大 part 数量 | 1,000 | 50 |
| 最大 header 大小 | 8 KB | 4 KB |
| 最大字段大小 | 1 MB | 64 KB |
| 最大文件大小 | 100 MB | 10 MB |
| 最大总请求体 | 500 MB | 50 MB |
| 最大文件名长度 | 255 | 255 |

## 项目规模

- **3,246 行**有效 MoonBit 代码（含测试和 CLI）
- **96 个**测试用例
- **8 个**源码模块
- Mooncakes 正式版本：`GCodinggo/moon-multipart@0.3.2`

## RFC 7578 合规矩阵

| 项目 | 状态 |
|------|------|
| CRLF + `--` + boundary 分隔符 | ✅ |
| 首 boundary 可选前缀 CRLF | ✅ |
| boundary 参数必需 | ✅ |
| 引号 boundary | ✅ |
| boundary 长度 1-70 | ✅ |
| closing boundary `--` 后缀 | ✅ |
| Content-Disposition 必需 | ✅ |
| `name` 参数必需 | ✅ |
| `filename` 参数可选 | ✅ |
| 同名字段多次出现 | ✅ MultipartForm |
| preamble 忽略 | ✅ |
| epilogue 忽略 | ✅ |
| `filename*` (RFC 5987) | ✅ Strict 拒绝 / Compat 接受 |
| 路径穿越防护 | ✅ |
| 流式解析（不缓存文件） | ✅ PartData 逐块输出 |

## Contributing

Development and verification instructions are available in [CONTRIBUTING.md](CONTRIBUTING.md).

## 许可证

Apache-2.0
