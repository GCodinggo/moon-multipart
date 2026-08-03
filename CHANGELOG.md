# Changelog

## 0.2.0 (2026-07-30)

### New Features

- **ParseOptions & ParseMode** — Strict/Compatible dual-mode parsing with configurable options
- **MultipartForm** — High-level API with ordered parts, same-name field/file support
- **StreamingWriter** — `begin_part` / `write_chunk` / `end_part` API for large file uploads
- **safe_filename module** — `validate_filename()`, `safe_filename()`, `unique_filename()`
- **parse_all()** — One-shot convenience function returning MultipartForm
- **Finished event** — Explicit parse completion signaling
- **Expanded errors** — MissingDisposition, FilenameTooLong, NonCompliantHeader, InvalidEncoding

### Improvements

- Limits struct now includes `max_filename_len` (6 dimensions)
- Content-Disposition parsing with strict mode (rejects `filename*`) and compatible mode (accepts it)
- Path traversal detection covers `..`, `\`, `/`, drive letters, null bytes
- Expanded tests from 29 to 87
- Code from ~2,300 to ~3,650 lines
- 8 source modules (up from 6)

## 0.1.0 (2026-07-29)

- Initial release
- RFC 7578 multipart/form-data streaming parser
- Multipart body generator (MultipartWriter)
- Content-Type boundary parsing
- Content-Disposition header parsing (name, filename)
- Configurable security limits (Limits)
- Path traversal detection in filenames
- 29 test cases covering parsing, generation, edge cases, and limits
