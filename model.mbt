// ===========================================================================
// moon-multipart — Core data model
// ===========================================================================

// ---------------------------------------------------------------------------
// Security limits
// ---------------------------------------------------------------------------

///|
/// Configurable security limits for multipart parsing.
/// Set any field to `-1` for unlimited.
pub(all) struct Limits {
  /// Maximum total parts allowed (default 1000)
  max_parts : Int
  /// Maximum header block size per part in bytes (default 8192)
  max_header_size : Int
  /// Maximum text field value in bytes (default 1 MB)
  max_field_size : Int
  /// Maximum file upload in bytes (default 100 MB)
  max_file_size : Int
  /// Maximum total request body in bytes (default 500 MB)
  max_total_size : Int
  /// Maximum filename length in characters (default 255)
  max_filename_len : Int
} derive(Debug)

///|
pub fn Limits::default() -> Limits {
  {
    max_parts: 1000,
    max_header_size: 8192,
    max_field_size: 1048576,
    max_file_size: 104857600,
    max_total_size: 524288000,
    max_filename_len: 255,
  }
}

///|
pub fn Limits::permissive() -> Limits {
  {
    max_parts: 100000,
    max_header_size: 65536,
    max_field_size: 104857600,
    max_file_size: 1073741824,
    max_total_size: -1,
    max_filename_len: 1024,
  }
}

///|
pub fn Limits::strict() -> Limits {
  {
    max_parts: 50,
    max_header_size: 4096,
    max_field_size: 65536,
    max_file_size: 10485760,
    max_total_size: 52428800,
    max_filename_len: 255,
  }
}

// ---------------------------------------------------------------------------
// Parse mode
// ---------------------------------------------------------------------------

///|
/// Parsing strictness mode.
pub(all) enum ParseMode {
  /// Strict RFC 7578 compliance: reject non-standard constructs like filename*
  Strict
  /// Compatible mode: accept common extensions with warnings
  Compatible
} derive(Eq, Debug)

///|
/// Options controlling parser behavior.
pub(all) struct ParseOptions {
  /// Parsing mode (Strict or Compatible)
  mode : ParseMode
  /// Security limits
  limits : Limits
  /// In strict mode, reject filename* (RFC 5987) parameters
  reject_filename_star : Bool
} derive(Debug)

///|
pub fn ParseOptions::default() -> ParseOptions {
  { mode: Compatible, limits: Limits::default(), reject_filename_star: true }
}

///|
pub fn ParseOptions::strict_rfc() -> ParseOptions {
  { mode: Strict, limits: Limits::default(), reject_filename_star: true }
}

///|
pub fn ParseOptions::compatible() -> ParseOptions {
  { mode: Compatible, limits: Limits::default(), reject_filename_star: false }
}

// ---------------------------------------------------------------------------
// Part types
// ---------------------------------------------------------------------------

///|
/// A single parsed multipart part — either a text field or a file upload.
pub(all) enum Part {
  /// Text form field: (name, value)
  Field(String, String)
  /// File upload: (name, filename, content_type?, data)
  File(String, String, String?, Bytes)
} derive(Debug)

///|
pub fn Part::name(self : Part) -> String {
  match self {
    Field(name, _) => name
    File(name, _, _, _) => name
  }
}

///|
pub fn Part::value(self : Part) -> String? {
  match self {
    Field(_, v) => Some(v)
    File(_, _, _, _) => None
  }
}

///|
pub fn Part::filename(self : Part) -> String? {
  match self {
    Field(_, _) => None
    File(_, f, _, _) => Some(f)
  }
}

///|
pub fn Part::content_type(self : Part) -> String? {
  match self {
    Field(_, _) => None
    File(_, _, ct, _) => ct
  }
}

///|
pub fn Part::data(self : Part) -> Bytes? {
  match self {
    Field(_, _) => None
    File(_, _, _, d) => Some(d)
  }
}

///|
pub fn Part::is_field(self : Part) -> Bool {
  match self {
    Field(_, _) => true
    _ => false
  }
}

///|
pub fn Part::is_file(self : Part) -> Bool {
  match self {
    File(_, _, _, _) => true
    _ => false
  }
}

// ---------------------------------------------------------------------------
// MultipartForm — high-level parse result
// ---------------------------------------------------------------------------

///|
/// High-level result of parsing a complete multipart body.
/// Preserves insertion order and supports same-name fields/files.
pub(all) struct MultipartForm {
  /// All parts in original order
  parts : Array[Part]
} derive(Debug)

///|
pub fn MultipartForm::new() -> MultipartForm {
  { parts: [] }
}

///|
/// Get ALL field values with the given name (supports same-name fields).
pub fn MultipartForm::field_values(
  self : MultipartForm,
  name : String,
) -> Array[String] {
  let result : Array[String] = []
  for part in self.parts {
    match part {
      Field(n, v) => if n == name { result.push(v.to_string()) } else { () }
      _ => ()
    }
  }
  result
}

///|
/// Get the first field value with the given name (convenience).
pub fn MultipartForm::field(self : MultipartForm, name : String) -> String? {
  for part in self.parts {
    match part {
      Field(n, v) => if n == name { return Some(v.to_string()) } else { () }
      _ => ()
    }
  }
  None
}

///|
/// Get ALL file parts with the given field name (supports multi-file upload).
pub fn MultipartForm::files(self : MultipartForm, name : String) -> Array[Part] {
  let result : Array[Part] = []
  for part in self.parts {
    match part {
      File(n, _, _, _) => if n == name { result.push(part) } else { () }
      _ => ()
    }
  }
  result
}

///|
/// Get the first file with the given field name (convenience).
pub fn MultipartForm::file(self : MultipartForm, name : String) -> Part? {
  for part in self.parts {
    match part {
      File(n, _, _, _) => if n == name { return Some(part) } else { () }
      _ => ()
    }
  }
  None
}

///|
/// Total number of parts.
pub fn MultipartForm::len(self : MultipartForm) -> Int {
  self.parts.length()
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

///|
/// Errors that can occur during multipart parsing or generation.
pub(all) enum MultipartError {
  MissingBoundary
  InvalidBoundary(String)
  HeaderTooLarge(Int)
  FieldTooLarge(String, Int)
  FileTooLarge(String, Int)
  TotalSizeExceeded(Int)
  TooManyParts(Int)
  MalformedHeader(String)
  MissingName
  MissingDisposition
  PathTraversal(String)
  FilenameTooLong(String, Int)
  IncompleteBody
  InvalidEncoding(String)
  NonCompliantHeader(String)
  ProcessingError(String)
} derive(Debug)

///|
pub fn MultipartError::to_string(self : MultipartError) -> String {
  match self {
    MissingBoundary => "Missing boundary parameter in Content-Type header"
    InvalidBoundary(s) => "Invalid boundary: " + s
    HeaderTooLarge(n) =>
      "Part header exceeds max size " + n.to_string() + " bytes"
    FieldTooLarge(name, n) =>
      "Field '" + name + "' exceeds max size " + n.to_string() + " bytes"
    FileTooLarge(name, n) =>
      "File '" + name + "' exceeds max size " + n.to_string() + " bytes"
    TotalSizeExceeded(n) =>
      "Total body exceeds max size " + n.to_string() + " bytes"
    TooManyParts(n) => "Too many parts: " + n.to_string()
    MalformedHeader(s) => "Malformed header: " + s
    MissingName => "Missing required 'name' parameter in Content-Disposition"
    MissingDisposition => "Missing Content-Disposition header in part"
    PathTraversal(s) => "Path traversal detected: " + s
    FilenameTooLong(name, n) =>
      "Filename '" + name + "' exceeds max length " + n.to_string()
    IncompleteBody => "Incomplete multipart body, closing boundary not found"
    InvalidEncoding(s) => "Invalid encoding: " + s
    NonCompliantHeader(s) => "Non-compliant header (strict mode): " + s
    ProcessingError(s) => "Processing error: " + s
  }
}

// ---------------------------------------------------------------------------
// Internal parser state machine
// ---------------------------------------------------------------------------

///|
enum ParsePhase {
  Preamble
  Headers
  Body
  BoundarySeen
  Done
}

// ---------------------------------------------------------------------------
// Streaming parse events
// ---------------------------------------------------------------------------

///|
/// Events emitted during streaming multipart parsing.
pub(all) enum ParseEvent {
  /// A new part is starting: (name, filename?, content_type?)
  PartBegin(String, String?, String?)
  /// A chunk of body data for the current part
  PartData(Bytes)
  /// The current part is complete
  PartEnd
  /// All parts have been parsed successfully
  Finished
} derive(Debug)
