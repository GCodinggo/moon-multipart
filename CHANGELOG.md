# Changelog

## 0.3.2 (2026-08-21)

### Changed

- Verified all 96 tests on native, JavaScript, wasm, and wasm-gc with the current MoonBit toolchain
- Extended GitHub Actions to all four targets and enabled warning-as-error checks
- Refreshed generated interfaces, project statistics, and final-acceptance documentation
- Kept the core library transport-neutral; HTTP framework integration remains the caller's responsibility

## 0.3.1 (2026-08-03)

### Fixed

- 清理测试中的三个未使用变量警告，保持原有测试覆盖目标不变
- 排除比赛申请书、PDF 等非库运行材料，避免进入 Mooncakes 发布包
- 不修改公共 API

## 0.3.0 (2026-08-01)

### Added

- CRLF injection protection for multipart header parameters, including field names, filenames, Content-Type values, and custom part headers
- Checked `MultipartWriter` and `StreamingWriter` APIs that return `MultipartError` instead of serializing unsafe input
- Extended Windows filename validation for reserved device names, UNC and drive paths, and trailing spaces or dots
- Regression coverage for CRLF injection, Unicode header parameters, and Windows filename safety rules

### Changed

- Corrected the documented maintainer, GitHub namespace, Mooncakes namespace, and package repository metadata
- Added contributor and historical Git identity documentation

### Fixed

- Replaced the placeholder copyright notice with the project copyright holder

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
