///|
/// A multipart/form-data body generator (RFC 7578 compliant).
pub(all) struct MultipartWriter {
  /// The generated boundary string
  boundary : String
  /// Internal buffer accumulating the complete body
  buf : @buffer.Buffer
  /// Total number of parts added so far
  mut part_count : Int
}

///|
/// Generate a unique boundary string for multipart messages.
fn generate_boundary() -> String {
  let base = "----MoonBitMultipart"
  let suffix = random_hex(16)
  base + suffix
}

///|
/// Generate a random hex string of the given length.
fn random_hex(length : Int) -> String {
  let hex = "0123456789ABCDEF"
  let buf = @buffer.Buffer()
  for i = 0; i < length; i = i + 1 {
    let idx = (i * 7 + 3) % 16
    let hex_bytes = @utf8.encode(hex)
    buf.write_byte(hex_bytes[idx])
  }
  buf.to_bytes().to_unchecked_string()
}

///|
/// Create a new multipart writer with a generated boundary.
pub fn MultipartWriter::new() -> MultipartWriter {
  MultipartWriter::{
    boundary: generate_boundary(),
    buf: @buffer.Buffer(),
    part_count: 0,
  }
}

///|
/// Create a multipart writer with a specific boundary string.
pub fn MultipartWriter::with_boundary(boundary : String) -> MultipartWriter {
  MultipartWriter::{ boundary, buf: @buffer.Buffer(), part_count: 0 }
}

///|
/// Get the boundary string for use in the Content-Type header.
pub fn MultipartWriter::get_boundary(self : MultipartWriter) -> String {
  self.boundary.to_string()
}

///|
/// Get the current part count.
pub fn MultipartWriter::part_count(self : MultipartWriter) -> Int {
  self.part_count
}

///|
/// Add a text form field.
pub fn MultipartWriter::add_field(
  self : MultipartWriter,
  name : String,
  value : String,
) -> Unit {
  self.write_part_header(name, None, None)
  self.buf.write_bytes(@utf8.encode(value))
  self.part_count = self.part_count + 1
}

///|
/// Add a file upload.
pub fn MultipartWriter::add_file(
  self : MultipartWriter,
  name : String,
  filename : String,
  content_type : String?,
  data : Bytes,
) -> Unit {
  self.write_part_header(name, Some(filename), content_type)
  self.buf.write_bytes(data)
  self.part_count = self.part_count + 1
}

///|
/// Finalize and return the boundary and complete body bytes.
pub fn MultipartWriter::finish(self : MultipartWriter) -> (String, Bytes) {
  self.buf.write_bytes(b"\r\n--")
  self.buf.write_bytes(@utf8.encode(self.boundary))
  self.buf.write_bytes(b"--\r\n")
  (self.boundary.to_string(), self.buf.to_bytes())
}

///|
/// Write a part header block.
fn MultipartWriter::write_part_header(
  self : MultipartWriter,
  name : String,
  filename : String?,
  content_type : String?,
) -> Unit {
  if self.part_count > 0 {
    self.buf.write_bytes(b"\r\n")
  }
  self.buf.write_bytes(b"--")
  self.buf.write_bytes(@utf8.encode(self.boundary))
  self.buf.write_bytes(b"\r\n")

  // Content-Disposition
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

  // Content-Type (optional)
  match content_type {
    Some(ct) => {
      self.buf.write_bytes(b"Content-Type: ")
      self.buf.write_bytes(@utf8.encode(ct))
      self.buf.write_bytes(b"\r\n")
    }
    None => ()
  }

  // Empty line to end headers
  self.buf.write_bytes(b"\r\n")
}
