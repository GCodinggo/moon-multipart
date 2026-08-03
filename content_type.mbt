// ===========================================================================
// moon-multipart — Content-Type & Content-Disposition header parsing
// ===========================================================================

// ---------------------------------------------------------------------------
// Boundary validation & extraction
// ---------------------------------------------------------------------------

///|
pub fn validate_boundary(boundary : String) -> Result[String, MultipartError] {
  let len = boundary.length()
  if len == 0 {
    return Err(InvalidBoundary("boundary must not be empty".to_string()))
  }
  if len > 70 {
    return Err(InvalidBoundary("boundary exceeds 70 chars: " + len.to_string()))
  }
  let bytes = @utf8.encode(boundary)
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i]
    if b < b' ' || b > b'~' {
      return Err(InvalidBoundary("illegal char at position " + i.to_string()))
    }
  }
  Ok(boundary.to_string())
}

///|
pub fn parse_boundary_from_content_type(
  content_type : String,
) -> Result[String, MultipartError] {
  let bytes = @utf8.encode(content_type)
  match find_param(bytes, b"boundary") {
    None => Err(MissingBoundary)
    Some(eq_pos) =>
      match extract_value(content_type, eq_pos) {
        None => Err(MissingBoundary)
        Some(v) => validate_boundary(v)
      }
  }
}

// ---------------------------------------------------------------------------
// Content-Disposition parsing (with strict/compat mode)
// ---------------------------------------------------------------------------

///|
/// Parse Content-Disposition header. Returns (name, filename?).
/// In strict mode with reject_filename_star, filename* is rejected.
pub fn parse_content_disposition(
  header_value : String,
  opts : ParseOptions,
) -> Result[(String, String?), MultipartError] {
  let trimmed = header_value.trim().to_owned()
  if !trimmed.has_prefix("form-data") {
    return Err(MalformedHeader("must start with 'form-data'".to_string()))
  }
  let name = extract_named_param(header_value, "name")

  // Check for filename* (RFC 5987, rejected by RFC 7578)
  let fstar = extract_named_param(header_value, "filename*")
  match fstar {
    Some(_) =>
      if opts.reject_filename_star {
        return Err(
          NonCompliantHeader("filename* is not allowed by RFC 7578".to_string()),
        )
      }
    None => ()
  }

  let filename = if opts.reject_filename_star {
    extract_named_param(header_value, "filename")
  } else {
    match fstar {
      Some(fs) => Some(fs)
      None => extract_named_param(header_value, "filename")
    }
  }

  match name {
    None => Err(MissingName)
    Some(n) => {
      // Validate filename
      match filename {
        Some(f) => {
          if f.length() > opts.limits.max_filename_len {
            return Err(
              FilenameTooLong(f.to_string(), opts.limits.max_filename_len),
            )
          }
          if is_dangerous(f) {
            return Err(PathTraversal(f.to_string()))
          }
        }
        None => ()
      }
      Ok((n, filename))
    }
  }
}

///|
/// Legacy parse_content_disposition without options (backwards compat).
pub fn parse_content_disposition_simple(
  header_value : String,
) -> Result[(String, String?), MultipartError] {
  parse_content_disposition(header_value, ParseOptions::default())
}

// ---------------------------------------------------------------------------
// Parameter extraction
// ---------------------------------------------------------------------------

///|
fn find_param(header_bytes : Bytes, param_name : Bytes) -> Int? {
  let hlen = header_bytes.length()
  let plen = param_name.length()
  if hlen < plen {
    return None
  }
  let mut i = 0
  while i <= hlen - plen {
    let mut matched = true
    let mut j = 0
    while j < plen {
      if ascii_lower(header_bytes[i + j]) != ascii_lower(param_name[j]) {
        matched = false
        j = plen
      } else {
        j = j + 1
      }
    }
    if matched {
      let before_ok = i == 0 ||
        header_bytes[i - 1] == b';' ||
        header_bytes[i - 1] == b' ' ||
        header_bytes[i - 1] == b'\t'
      let mut k = i + plen
      while k < hlen && (header_bytes[k] == b' ' || header_bytes[k] == b'\t') {
        k = k + 1
      }
      if before_ok && k < hlen && header_bytes[k] == b'=' {
        return Some(k)
      }
    }
    i = i + 1
  }
  None
}

///|
fn ascii_lower(b : Byte) -> Byte {
  let v = b.to_int()
  if v >= 65 && v <= 90 {
    (v + 32).to_byte()
  } else {
    b
  }
}

///|
fn extract_value(header : String, eq_pos : Int) -> String? {
  let total = header.length()
  let mut start = eq_pos + 1
  while start < total {
    let c = header[start]
    if c == ' ' || c == '\t' {
      start = start + 1
    } else {
      break
    }
  }
  if start >= total {
    return None
  }
  if header[start] == '"' {
    let mut end = start + 1
    while end < total {
      if header[end] == '"' {
        return Some(header[start + 1:end].to_owned())
      }
      if header[end] == '\\' && end + 1 < total {
        end = end + 1
      }
      end = end + 1
    }
    return Some(header[start + 1:].to_owned())
  }
  let mut end = start
  while end < total {
    if header[end] == ';' {
      break
    }
    end = end + 1
  }
  Some(header[start:end].trim().to_owned())
}

///|
fn extract_named_param(header_val : String, param_name : String) -> String? {
  let hb = @utf8.encode(header_val)
  let pb = @utf8.encode(param_name)
  match find_param(hb, pb) {
    None => None
    Some(pos) => extract_value(header_val, pos)
  }
}

// ---------------------------------------------------------------------------
// Header line parsing
// ---------------------------------------------------------------------------

///|
pub fn parse_header_line(line : String) -> (String, String)? {
  match line.find(":") {
    None => None
    Some(i) => {
      let name = line[0:i].trim().to_owned()
      let value = line[i + 1:].trim().to_owned()
      if name.length() > 0 {
        Some((name, value))
      } else {
        None
      }
    }
  }
}

///|
pub fn is_content_type(name : String) -> Bool {
  name.trim().equal_ignore_ascii_case("content-type")
}

///|
pub fn is_content_disposition(name : String) -> Bool {
  name.trim().equal_ignore_ascii_case("content-disposition")
}

// ---------------------------------------------------------------------------
// Filename danger detection
// ---------------------------------------------------------------------------

///|
fn is_dangerous(filename : String) -> Bool {
  if filename.contains("..") {
    return true
  }
  if filename.contains("\\") {
    return true
  }
  if filename.has_prefix("/") || filename.has_prefix("\\\\") {
    return true
  }
  // Null byte check via byte scan
  let fbytes_check = @utf8.encode(filename)
  let mut has_null = false
  for i = 0; i < fbytes_check.length(); i = i + 1 {
    if fbytes_check[i] == b'\x00' {
      has_null = true
    }
  }
  if has_null {
    return true
  }
  let fbytes = @utf8.encode(filename)
  if fbytes.length() >= 2 && is_ascii_alpha(fbytes[0]) && fbytes[1] == b':' {
    return true
  }
  false
}

///|
fn is_ascii_alpha(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
}
