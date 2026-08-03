///|
/// # moon-multipart
///
/// 面向 MoonBit HTTP 生态的流式 multipart/form-data 解析与生成库。
///
/// 完整实现 RFC 7578 (multipart/form-data) 标准，支持流式解析、安全限制、
/// 跨分块边界检测和 multipart 消息体生成。
///
/// ## Quick Start
///
/// ### Parse a multipart body
///
/// ```mbt
/// let content_type = "multipart/form-data; boundary=----WebKitFormBoundary"
/// let boundary = parse_boundary_from_content_type(content_type)?
/// let parser = Parser::new(boundary, Limits::default())
/// for chunk in incoming_chunks {
///   let events = parser.feed(chunk)?
///   for event in events {
///     match event {
///       PartBegin(name, filename, content_type) => { ... }
///       PartData(data) => { ... }
///       PartEnd => { ... }
///     }
///   }
/// }
/// parser.finish()?
/// ```
///
/// ### Generate a multipart body
///
/// ```mbt
/// let writer = MultipartWriter::new()
/// writer.add_field("username", "alice")
/// writer.add_file("avatar", "photo.png", Some("image/png"), image_bytes)
/// let (boundary, body) = writer.finish()
/// // Set header: Content-Type: multipart/form-data; boundary=<boundary>
/// ```
///
/// ## Features
///
/// - **RFC 7578 compliant** — full support for multipart/form-data encoding
/// - **Streaming parser** — process large uploads without buffering entire body
/// - **Split boundary detection** — handles boundaries split across network chunks
/// - **Security limits** — configurable limits for parts, fields, files, and total size
/// - **Path traversal protection** — detects and rejects `../` sequences in filenames
/// - **Multipart generator** — build multipart bodies for file uploads
///
/// ## License
///
/// Apache-2.0
