# Contributing

Thanks for your interest in moon-multipart.

## Development Requirements

Install the latest stable MoonBit toolchain and clone the repository:

```bash
git clone https://github.com/Songyz002/moon-multipart.git
cd moon-multipart
```

## Local Verification

Before submitting a change, run:

```bash
moon fmt
moon check
moon build
moon test
moon package --list
```

All checks should pass before the change is committed.

## Contribution Guidelines

- Keep changes focused and easy to review.
- Add tests when introducing new behavior or fixing a bug.
- Preserve deterministic behavior across MoonBit targets (native / js / wasm-gc).
- Do not include sensitive values in tests, examples, or reports.
- Update the documentation when public APIs or command-line behavior change.
- Follow the existing code style (`moon fmt` enforces formatting automatically).

## Commit Messages

Use concise commit messages that describe the purpose of the change, for example:

```
docs: improve contribution guide
test: add split-chunk boundary coverage
fix: handle unclosed quote in Content-Disposition
feat: add unique_filename helper
```

## Project Structure

| Path | Purpose |
|------|---------|
| `model.mbt` | Core data types (Limits, Part, MultipartForm, errors) |
| `parser.mbt` | Streaming RFC 7578 parser |
| `content_type.mbt` | Content-Type and Content-Disposition header parsing |
| `boundary_matcher.mbt` | Streaming boundary delimiter detector |
| `writer.mbt` | Multipart body generator |
| `streaming_writer.mbt` | Chunked multipart body writer |
| `safe_filename.mbt` | Upload filename validation and sanitization |
| `moon-multipart.mbt` | Package documentation |
| `multipart_test.mbt` | Test suite |
| `cmd/main/` | CLI roundtrip demo |
| `docs/` | Documentation and submission materials |
