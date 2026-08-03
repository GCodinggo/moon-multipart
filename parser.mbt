// ===========================================================================
// moon-multipart — Streaming RFC 7578 multipart/form-data parser
// ===========================================================================

///|
/// Streaming multipart parser. Feed byte chunks and receive ParseEvents.
/// Never buffers an entire file in memory — body data is emitted as PartData.
pub(all) struct Parser {
  boundary : String
  delimiter : Bytes
  boundary_prefix : Bytes
  delimiter_len : Int
  options : ParseOptions
  buf : @buffer.Buffer
  mut phase : ParsePhase
  body_buf : @buffer.Buffer
  mut part_name : String
  mut part_filename : String?
  mut part_content_type : String?
  mut part_is_file : Bool
  mut part_count : Int
  mut total_size : Int
  mut first_boundary_found : Bool
  mut finished : Bool
  /// Byte offset from start of input (approximate, for error context)
  mut offset : Int
}

///|
/// Create a new streaming parser.
pub fn Parser::new(boundary : String, options : ParseOptions) -> Parser {
  let prefix = @utf8.encode("--" + boundary)
  let delim = @utf8.encode("\r\n--" + boundary)
  Parser::{
    boundary: boundary.to_string(),
    delimiter: delim,
    boundary_prefix: prefix,
    delimiter_len: delim.length(),
    options,
    buf: @buffer.Buffer(),
    phase: Preamble,
    body_buf: @buffer.Buffer(),
    part_name: "",
    part_filename: None,
    part_content_type: None,
    part_is_file: false,
    part_count: 0,
    total_size: 0,
    first_boundary_found: false,
    finished: false,
    offset: 0,
  }
}

///|
/// Feed a chunk of bytes. Returns ParseEvents emitted during processing.
pub fn Parser::feed(
  self : Parser,
  chunk : Bytes,
) -> Result[Array[ParseEvent], MultipartError] {
  if self.finished {
    return Ok([])
  }
  let events : Array[ParseEvent] = []
  self.buf.write_bytes(chunk)
  self.total_size = self.total_size + chunk.length()
  self.offset = self.offset + chunk.length()

  // Total size check
  let lim = self.options.limits
  if lim.max_total_size > 0 && self.total_size > lim.max_total_size {
    return Err(TotalSizeExceeded(lim.max_total_size))
  }

  let mut progress = true
  while progress {
    progress = false
    let data = self.buf.to_bytes()
    match self.phase {
      Preamble =>
        match try_find_first(data, self.boundary_prefix, self.delimiter) {
          Err(e) => return Err(e)
          Ok(None) =>
            if data.length() > self.delimiter_len {
              let safe = data.length() - self.delimiter_len
              self.buf.reset()
              self.buf.write_bytes(bv(data[safe:]))
            }
          Ok(Some((_idx, consumed))) => {
            self.first_boundary_found = true
            self.buf.reset()
            if consumed < data.length() {
              self.buf.write_bytes(bv(data[consumed:]))
            }
            let after = self.buf.to_bytes()
            if after.length() >= 2 && after[0] == b'\r' && after[1] == b'\n' {
              self.buf.reset()
              if after.length() > 2 {
                self.buf.write_bytes(bv(after[2:]))
              }
              self.phase = Headers
              progress = true
            } else if after.length() >= 2 &&
              after[0] == b'-' &&
              after[1] == b'-' {
              self.buf.reset()
              if after.length() > 2 {
                self.buf.write_bytes(bv(after[2:]))
              }
              self.phase = Done
              self.finished = true
              events.push(Finished)
              progress = true
            }
          }
        }
      Headers =>
        match find_double_crlf(data) {
          None =>
            if lim.max_header_size > 0 && data.length() > lim.max_header_size {
              return Err(HeaderTooLarge(lim.max_header_size))
            }
          Some(end_idx) => {
            let hdr_str = bytes_str(data[0:end_idx])
            self.buf.reset()
            if end_idx + 4 < data.length() {
              self.buf.write_bytes(bv(data[end_idx + 4:]))
            }
            match parse_part_headers(hdr_str, self.options) {
              Err(e) => return Err(e)
              Ok((name, filename, ct)) => {
                self.part_count = self.part_count + 1
                if lim.max_parts > 0 && self.part_count > lim.max_parts {
                  return Err(TooManyParts(lim.max_parts))
                }
                self.part_name = name.to_string()
                self.part_filename = clone_opt(filename)
                self.part_content_type = clone_opt(ct)
                self.part_is_file = match filename {
                  Some(_) => true
                  None => false
                }
                self.body_buf.reset()
                events.push(
                  PartBegin(
                    self.part_name.to_string(),
                    clone_opt(self.part_filename),
                    clone_opt(self.part_content_type),
                  ),
                )
                self.phase = Body
                progress = true
              }
            }
          }
        }
      Body => {
        let (body_bytes, consumed, found, closing) = scan_body(
          data,
          self.delimiter,
          self.delimiter_len,
        )
        if body_bytes.length() > 0 {
          // Size checks
          if self.part_is_file {
            if lim.max_file_size > 0 &&
              self.body_buf.length() + body_bytes.length() > lim.max_file_size {
              return Err(
                FileTooLarge(self.part_name.to_string(), lim.max_file_size),
              )
            }
          } else if lim.max_field_size > 0 &&
            self.body_buf.length() + body_bytes.length() > lim.max_field_size {
            return Err(
              FieldTooLarge(self.part_name.to_string(), lim.max_field_size),
            )
          }
          self.body_buf.write_bytes(body_bytes)
          events.push(PartData(body_bytes))
        }
        if found {
          events.push(PartEnd)
          self.buf.reset()
          if consumed < data.length() {
            self.buf.write_bytes(bv(data[consumed:]))
          }
          let after = self.buf.to_bytes()
          if closing {
            self.buf.reset()
            if after.length() > 2 {
              self.buf.write_bytes(bv(after[2:]))
            }
            self.phase = Done
            self.finished = true
            events.push(Finished)
            progress = true
          } else if after.length() >= 2 &&
            after[0] == b'\r' &&
            after[1] == b'\n' {
            self.buf.reset()
            if after.length() > 2 {
              self.buf.write_bytes(bv(after[2:]))
            }
            self.phase = Headers
            progress = true
          } else if after.length() < 2 {
            self.phase = BoundarySeen
            progress = true
          } else {
            return Err(
              MalformedHeader("Unexpected data after delimiter".to_string()),
            )
          }
        }
      }
      BoundarySeen => {
        let after = self.buf.to_bytes()
        if after.length() >= 2 {
          if after[0] == b'-' && after[1] == b'-' {
            self.buf.reset()
            if after.length() > 2 {
              self.buf.write_bytes(bv(after[2:]))
            }
            self.phase = Done
            self.finished = true
            events.push(Finished)
            progress = true
          } else if after[0] == b'\r' && after[1] == b'\n' {
            self.buf.reset()
            if after.length() > 2 {
              self.buf.write_bytes(bv(after[2:]))
            }
            events.push(PartEnd)
            self.phase = Headers
            progress = true
          } else {
            return Err(
              MalformedHeader("Unexpected data after delimiter".to_string()),
            )
          }
        }
      }
      Done => self.buf.reset()
    }
  }
  Ok(events)
}

///|
/// Signal end of input. Returns error if body was incomplete.
pub fn Parser::finish(
  self : Parser,
) -> Result[Array[ParseEvent], MultipartError] {
  if self.finished {
    return Ok([])
  }
  let events : Array[ParseEvent] = []
  match self.phase {
    Preamble =>
      if !self.first_boundary_found {
        return Err(IncompleteBody)
      } else {
        ()
      }
    Headers => return Err(IncompleteBody)
    Body => return Err(IncompleteBody)
    BoundarySeen =>
      if self.buf.to_bytes().length() < 2 {
        return Err(IncompleteBody)
      } else {
        ()
      }
    Done => ()
  }
  self.finished = true
  events.push(Finished)
  Ok(events)
}

///|
/// Is parsing complete?
pub fn Parser::is_finished(self : Parser) -> Bool {
  self.finished
}

// ---------------------------------------------------------------------------
// High-level convenience API
// ---------------------------------------------------------------------------

///|
/// Parse a complete multipart body in one shot.
/// Convenience wrapper that feeds all bytes at once and collects all parts.
pub fn parse_all(
  body : Bytes,
  boundary : String,
  options : ParseOptions,
) -> Result[MultipartForm, MultipartError] {
  let parser = Parser::new(boundary, options)
  let form = MultipartForm::new()
  match parser.feed(body) {
    Err(e) => return Err(e)
    Ok(evts) => collect_events(form, evts)
  }
  match parser.finish() {
    Err(e) => return Err(e)
    Ok(evts) => collect_events(form, evts)
  }
  Ok(form)
}

///|
fn collect_events(form : MultipartForm, events : Array[ParseEvent]) -> Unit {
  let mut cur_name : String? = None
  let mut cur_filename : String? = None
  let mut cur_ct : String? = None
  let cur_data = @buffer.Buffer()
  for evt in events {
    match evt {
      PartBegin(n, f, ct) => {
        cur_name = Some(n)
        cur_filename = f
        cur_ct = ct
        cur_data.reset()
      }
      PartData(d) => cur_data.write_bytes(d)
      PartEnd => {
        let nm = match cur_name {
          Some(x) => x
          None => continue
        }
        match cur_filename {
          Some(fname) => {
            let ct_val = match cur_ct {
              Some(c) => Some(c)
              None => None
            }
            let file_data = cur_data.to_bytes()
            form.parts.push(File(nm, fname, ct_val, file_data))
          }
          None => {
            let field_bytes = cur_data.to_bytes()
            let chars : Array[Char] = []
            for bi = 0; bi < field_bytes.length(); bi = bi + 1 {
              chars.push(field_bytes[bi].to_char())
            }
            form.parts.push(Field(nm, String::from_array(chars)))
          }
        }
      }
      Finished => ()
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers — boundary detection
// ---------------------------------------------------------------------------

///|
fn try_find_first(
  data : Bytes,
  prefix : Bytes,
  delimiter : Bytes,
) -> Result[(Int, Int)?, MultipartError] {
  let plen = prefix.length()
  let dlen = delimiter.length()
  // Try --boundary at position 0
  if data.length() >= plen && byte_eq(data, 0, prefix) {
    let mut c = plen
    let dl = data.length()
    while c < dl && (data[c] == b' ' || data[c] == b'\t') {
      c = c + 1
    }
    return Ok(Some((0, c)))
  }
  // Try \r\n--boundary
  if data.length() >= dlen {
    match find_bytes(data, delimiter, 0) {
      Some(i) => {
        let mut c = i + dlen
        let dl2 = data.length()
        while c < dl2 && (data[c] == b' ' || data[c] == b'\t') {
          c = c + 1
        }
        Ok(Some((i, c)))
      }
      None => Ok(None)
    }
  } else {
    Ok(None)
  }
}

///|
fn scan_body(
  data : Bytes,
  delimiter : Bytes,
  dlen : Int,
) -> (Bytes, Int, Bool, Bool) {
  let dl = data.length()
  if dl < dlen {
    return (b"", 0, false, false)
  }
  match find_bytes(data, delimiter, 0) {
    None => {
      let safe = dl - (dlen - 1)
      if safe <= 0 {
        return (b"", 0, false, false)
      }
      (bv(data[0:safe]), safe, false, false)
    }
    Some(i) => {
      let body = if i > 0 { bv(data[0:i]) } else { b"" }
      let after = i + dlen
      let closing = after + 1 < dl &&
        data[after] == b'-' &&
        data[after + 1] == b'-'
      let consumed = if closing { after + 2 } else { after }
      (body, consumed, true, closing)
    }
  }
}

///|
fn find_double_crlf(data : Bytes) -> Int? {
  let len = data.length()
  let mut i = 0
  while i + 3 < len {
    if data[i] == b'\r' &&
      data[i + 1] == b'\n' &&
      data[i + 2] == b'\r' &&
      data[i + 3] == b'\n' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

// ---------------------------------------------------------------------------
// Header parsing (with strict/compat mode)
// ---------------------------------------------------------------------------

///|
fn parse_part_headers(
  hdr_block : String,
  opts : ParseOptions,
) -> Result[(String, String?, String?), MultipartError] {
  let mut name : String? = None
  let mut filename : String? = None
  let mut content_type : String? = None
  let mut has_disposition = false

  let lines = hdr_block.split("\r\n")
  for line in lines {
    let line_str = line.to_owned()
    if line_str.length() == 0 {
      continue
    }
    match parse_header_line(line_str) {
      None => continue
      Some((hn, hv)) =>
        if is_content_type(hn) {
          content_type = Some(hv)
        } else if is_content_disposition(hn) {
          has_disposition = true
          match parse_content_disposition(hv, opts) {
            Err(e) => return Err(e)
            Ok((n, f)) => {
              name = Some(n)
              filename = f
            }
          }
        }
    }
  }
  if !has_disposition {
    return Err(MissingDisposition)
  }
  match name {
    None => Err(MissingName)
    Some(n) => Ok((n, filename, content_type))
  }
}

// ---------------------------------------------------------------------------
// Byte utilities
// ---------------------------------------------------------------------------

///|
fn byte_eq(data : Bytes, start : Int, pattern : Bytes) -> Bool {
  let pl = pattern.length()
  if start + pl > data.length() {
    return false
  }
  let mut i = 0
  while i < pl {
    if data[start + i] != pattern[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn find_bytes(data : Bytes, pattern : Bytes, from : Int) -> Int? {
  let bl = data.length()
  let pl = pattern.length()
  if pl == 0 || bl < pl {
    return None
  }
  let mut i = from
  while i <= bl - pl {
    if byte_eq(data, i, pattern) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn bytes_str(view : BytesView) -> String {
  let b = @buffer.Buffer()
  b.write_bytesview(view)
  let bytes = b.to_bytes()
  let chars : Array[Char] = []
  for i = 0; i < bytes.length(); i = i + 1 {
    chars.push(bytes[i].to_char())
  }
  String::from_array(chars)
}

///|
fn bv(view : BytesView) -> Bytes {
  let b = @buffer.Buffer()
  b.write_bytesview(view)
  b.to_bytes()
}

///|
fn clone_opt(opt : String?) -> String? {
  match opt {
    None => None
    Some(s) => Some(s.to_string())
  }
}
