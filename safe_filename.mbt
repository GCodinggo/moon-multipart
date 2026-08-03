// ===========================================================================
// moon-multipart — Safe filename handling
// ===========================================================================

///|
/// Check if a filename contains path traversal or other dangerous patterns.
pub fn is_dangerous_filename(filename : String) -> Bool {
  if filename.contains("..") {
    return true
  }
  if filename.contains("\\") {
    return true
  }
  if filename.has_prefix("/") || filename.has_prefix("\\\\") {
    return true
  }
  let fb = @utf8.encode(filename)
  if fb.length() >= 2 && is_alpha(fb[0]) && fb[1] == b':' {
    return true
  }
  let mut has_null = false
  for i = 0; i < fb.length(); i = i + 1 {
    if fb[i] == b'\x00' {
      has_null = true
    }
  }
  if has_null {
    return true
  }
  false
}

///|
/// Validate a filename for security. Returns Ok(filename) or Err.
pub fn validate_filename(
  filename : String,
  max_len : Int,
) -> Result[String, MultipartError] {
  let trimmed = filename.trim().to_owned()
  if trimmed.length() == 0 {
    return Err(PathTraversal("empty filename".to_string()))
  }
  if trimmed.length() > max_len {
    return Err(FilenameTooLong(trimmed, max_len))
  }
  if is_dangerous_filename(trimmed) {
    return Err(PathTraversal(trimmed))
  }
  Ok(trimmed)
}

///|
/// Produce a safe, sanitized filename by removing dangerous characters.
pub fn safe_filename(original : String) -> String {
  let chars : Array[Char] = []
  let byte_data = @utf8.encode(original)
  let mut i = 0
  let blen = byte_data.length()
  while i < blen {
    let b = byte_data[i]
    if b == b'/' || b == b'\\' || b == b'\x00' {
      chars.push('_')
      i = i + 1
      continue
    }
    if i + 1 < blen && byte_data[i] == b'.' && byte_data[i + 1] == b'.' {
      chars.push('_')
      chars.push('_')
      i = i + 2
      continue
    }
    chars.push(b.to_char())
    i = i + 1
  }
  let result = String::from_array(chars)
  // Check for drive letter
  let rb = @utf8.encode(result)
  if rb.length() >= 2 && is_alpha(rb[0]) && rb[1] == b':' {
    return strip_dangerous(result[2:].to_owned())
  }
  strip_dangerous(result)
}

///|
/// Generate a unique safe filename preserving the original extension.
pub fn unique_filename(original : String) -> String {
  let safe = safe_filename(original)
  match safe.rev_find(".") {
    None => safe + "_" + hex8()
    Some(idx) => safe[0:idx].to_owned() + "_" + hex8() + safe[idx:].to_owned()
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

///|
fn is_alpha(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
}

///|
fn strip_dangerous(s : String) -> String {
  let bytes = @utf8.encode(s)
  let chars : Array[Char] = []
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i]
    if b >= b'0' && b <= b'9' {
      chars.push(b.to_char())
      continue
    }
    if b >= b'A' && b <= b'Z' {
      chars.push(b.to_char())
      continue
    }
    if b >= b'a' && b <= b'z' {
      chars.push(b.to_char())
      continue
    }
    if b == b'-' || b == b'_' || b == b'.' {
      chars.push(b.to_char())
    } else {
      chars.push('_')
    }
  }
  String::from_array(chars)
}

///|
fn hex8() -> String {
  let hex_chars = "0123456789ABCDEF".to_array()
  let chars : Array[Char] = []
  for i = 0; i < 8; i = i + 1 {
    let idx = (i * 13 + 7) % 16
    chars.push(hex_chars[idx])
  }
  String::from_array(chars)
}
