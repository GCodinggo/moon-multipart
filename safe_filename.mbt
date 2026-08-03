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
  if fb.length() > 0 &&
    (fb[fb.length() - 1] == b' ' || fb[fb.length() - 1] == b'.') {
    return true
  }
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
  if is_windows_reserved_name(filename) {
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
  if filename.trim().length() == 0 {
    return Err(PathTraversal("empty filename".to_string()))
  }
  if filename.length() > max_len {
    return Err(FilenameTooLong(filename, max_len))
  }
  if is_dangerous_filename(filename) {
    return Err(PathTraversal(filename))
  }
  Ok(filename.to_string())
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
  let result = trim_windows_tail(String::from_array(chars))
  // Check for drive letter
  let rb = @utf8.encode(result)
  if rb.length() >= 2 && is_alpha(rb[0]) && rb[1] == b':' {
    return make_windows_safe(strip_dangerous(result[2:].to_owned()))
  }
  make_windows_safe(strip_dangerous(result))
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
/// Remove trailing spaces and dots, which Windows silently discards.
fn trim_windows_tail(s : String) -> String {
  let bytes = @utf8.encode(s)
  let mut end = bytes.length()
  while end > 0 && (bytes[end - 1] == b' ' || bytes[end - 1] == b'.') {
    end = end - 1
  }
  if end == 0 {
    "_"
  } else {
    s[0:end].to_owned()
  }
}

///|
/// Prefix Windows device names so a sanitized filename is safe to create.
fn make_windows_safe(s : String) -> String {
  if is_windows_reserved_name(s) {
    "_" + s
  } else {
    s
  }
}

///|
/// Check Windows reserved device names, with or without an extension.
fn is_windows_reserved_name(filename : String) -> Bool {
  let stem = match filename.find(".") {
    Some(index) => filename[0:index].to_owned()
    None => filename.to_string()
  }
  let lower = stem.to_lower()
  if lower == "con" || lower == "prn" || lower == "aux" || lower == "nul" {
    return true
  }
  let bytes = @utf8.encode(lower)
  if bytes.length() != 4 || bytes[3] < b'1' || bytes[3] > b'9' {
    return false
  }
  (bytes[0] == b'c' && bytes[1] == b'o' && bytes[2] == b'm') ||
  (bytes[0] == b'l' && bytes[1] == b'p' && bytes[2] == b't')
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
