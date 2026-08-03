///|
/// A streaming boundary matcher that detects `\r\n--<boundary>` delimiters
/// in an incoming byte stream. Handles split boundaries across chunk boundaries.
pub(all) struct BoundaryMatcher {
  /// The full delimiter pattern: `\r\n--` + boundary
  delimiter : Bytes
  /// Length of the full delimiter
  delimiter_len : Int
  /// Accumulated buffer of bytes not yet confirmed as body data
  buf : @buffer.Buffer
}

///|
/// Result of feeding bytes to the boundary matcher.
pub(all) enum BoundaryMatch {
  /// A delimiter was found. Contains body bytes before delimiter and whether closing.
  Delimiter(Bytes, Bool)
  /// No delimiter found, but some bytes can be safely emitted as body data.
  Pending(Bytes)
  /// No data to report yet — need more input.
  NoData
}

///|
/// Create a new boundary matcher for the given boundary string.
pub fn BoundaryMatcher::new(boundary : String) -> BoundaryMatcher {
  let delim_str = "\r\n--" + boundary
  let delimiter = @utf8.encode(delim_str)
  { delimiter, delimiter_len: delimiter.length(), buf: @buffer.Buffer() }
}

///|
/// Feed a chunk of bytes into the boundary matcher.
pub fn BoundaryMatcher::feed(
  self : BoundaryMatcher,
  chunk : Bytes,
) -> BoundaryMatch {
  self.buf.write_bytes(chunk)
  let data = self.buf.to_bytes()
  let dlen = data.length()

  if dlen < self.delimiter_len {
    return NoData
  }

  let idx = find_byte_pattern(data, self.delimiter)
  match idx {
    None => {
      let safe_len = dlen - (self.delimiter_len - 1)
      if safe_len <= 0 {
        return NoData
      }
      let safe = bytesview_to_bytes(data[0:safe_len])
      let keep = bytesview_to_bytes(data[safe_len:])
      self.buf.reset()
      self.buf.write_bytes(keep)
      Pending(safe)
    }
    Some(i) => {
      let body_before = if i > 0 { bytesview_to_bytes(data[0:i]) } else { b"" }
      let after_delim = i + self.delimiter_len

      let closing = after_delim + 1 < dlen &&
        data[after_delim] == b'-' &&
        data[after_delim + 1] == b'-'

      self.buf.reset()
      let consumed = if closing { after_delim + 2 } else { after_delim }
      if consumed < dlen {
        self.buf.write_bytes(bytesview_to_bytes(data[consumed:]))
      }
      Delimiter(body_before, closing)
    }
  }
}

///|
/// Feed the final chunk and flush any remaining buffered bytes.
pub fn BoundaryMatcher::finish(self : BoundaryMatcher) -> Bytes {
  let remaining = self.buf.to_bytes()
  self.buf.reset()
  let out = @buffer.Buffer()
  out.write_bytesview(remaining)
  out.to_bytes()
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

///|
/// Find a byte pattern in a byte sequence. Returns index or None.
fn find_byte_pattern(haystack : Bytes, needle : Bytes) -> Int? {
  let h_len = haystack.length()
  let n_len = needle.length()
  if n_len == 0 || h_len < n_len {
    return None
  }
  let max_start = h_len - n_len
  let mut i = 0
  while i <= max_start {
    let mut matched = true
    let mut j = 0
    while j < n_len {
      if haystack[i + j] != needle[j] {
        matched = false
        j = n_len
      } else {
        j = j + 1
      }
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Convert a BytesView to Bytes.
fn bytesview_to_bytes(view : BytesView) -> Bytes {
  let b = @buffer.Buffer()
  b.write_bytesview(view)
  b.to_bytes()
}
