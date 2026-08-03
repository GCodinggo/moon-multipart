// ===========================================================================
// moon-multipart — Streaming multipart body writer
// ===========================================================================

///|
/// A streaming multipart writer that outputs body data in chunks.
/// Use `begin_part` / `write_chunk` / `end_part` instead of loading entire
/// files into memory before writing.
pub(all) struct StreamingWriter {
  boundary : String
  buf : @buffer.Buffer
  mut part_count : Int
  mut current_part_open : Bool
}

///|
/// Create a new streaming writer with the given boundary.
pub fn StreamingWriter::new(boundary : String) -> StreamingWriter {
  StreamingWriter::{
    boundary,
    buf: @buffer.Buffer(),
    part_count: 0,
    current_part_open: false,
  }
}

///|
/// Create a streaming writer with an auto-generated boundary.
pub fn StreamingWriter::with_random_boundary() -> StreamingWriter {
  StreamingWriter::new(generate_sw_boundary())
}

///|
/// Get the boundary string.
pub fn StreamingWriter::get_boundary(self : StreamingWriter) -> String {
  self.boundary.to_string()
}

///|
/// Begin a new part.
/// - `name`: Content-Disposition name parameter
/// - `filename`: Optional filename (None for text fields)
/// - `content_type`: Optional Content-Type for the part
pub fn StreamingWriter::begin_part(
  self : StreamingWriter,
  name : String,
  filename : String?,
  content_type : String?,
) -> Unit {
  match self.try_begin_part(name, filename, content_type) {
    Ok(_) => ()
    Err(e) => abort(e.to_string())
  }
}

///|
/// Begin a part while rejecting CRLF in every serialized header parameter.
pub fn StreamingWriter::try_begin_part(
  self : StreamingWriter,
  name : String,
  filename : String?,
  content_type : String?,
) -> Result[Unit, MultipartError] {
  match validate_part_headers(name, filename, content_type) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if self.part_count > 0 {
    self.buf.write_bytes(b"\r\n")
  }
  self.buf.write_bytes(b"--")
  self.buf.write_bytes(@utf8.encode(self.boundary))
  self.buf.write_bytes(b"\r\n")
  self.buf.write_bytes(b"Content-Disposition: form-data; name=\"")
  self.buf.write_bytes(@utf8.encode(name))
  self.buf.write_bytes(b"\"")
  match filename {
    Some(f) => {
      self.buf.write_bytes(b"; filename=\"")
      self.buf.write_bytes(@utf8.encode(f))
      self.buf.write_bytes(b"\"")
    }
    None => ()
  }
  self.buf.write_bytes(b"\r\n")
  match content_type {
    Some(ct) => {
      self.buf.write_bytes(b"Content-Type: ")
      self.buf.write_bytes(@utf8.encode(ct))
      self.buf.write_bytes(b"\r\n")
    }
    None => ()
  }
  self.buf.write_bytes(b"\r\n")
  self.current_part_open = true
  Ok(())
}

///|
/// Write a chunk of body data for the current part.
pub fn StreamingWriter::write_chunk(
  self : StreamingWriter,
  data : Bytes,
) -> Unit {
  self.buf.write_bytes(data)
}

///|
/// End the current part.
pub fn StreamingWriter::end_part(self : StreamingWriter) -> Unit {
  self.part_count = self.part_count + 1
  self.current_part_open = false
}

///|
/// Finalize and return the complete multipart body.
pub fn StreamingWriter::finish(self : StreamingWriter) -> Bytes {
  if self.current_part_open {
    self.end_part()
  }
  self.buf.write_bytes(b"\r\n--")
  self.buf.write_bytes(@utf8.encode(self.boundary))
  self.buf.write_bytes(b"--\r\n")
  self.buf.to_bytes()
}

///|
fn generate_sw_boundary() -> String {
  let hex = "0123456789ABCDEF"
  let buf = @buffer.Buffer()
  for i = 0; i < 16; i = i + 1 {
    buf.write_byte(@utf8.encode(hex)[(i * 7 + 3) % 16])
  }
  "----MoonBitMultipart" + buf.to_bytes().to_unchecked_string()
}
