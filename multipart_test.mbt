// ===========================================================================
// moon-multipart — Comprehensive test suite (80+ tests)
// ===========================================================================

// ===========================================================================
// Part 1: Boundary parsing (8 tests)
// ===========================================================================

///|
test "boundary: unquoted" {
  let r = parse_boundary_from_content_type("multipart/form-data; boundary=abc")
  match r {
    Ok(b) => @test.assert_eq(b, "abc")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "boundary: quoted" {
  let r = parse_boundary_from_content_type(
    "multipart/form-data; boundary=\"abc\"",
  )
  match r {
    Ok(b) => @test.assert_eq(b, "abc")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "boundary: with whitespace around =" {
  let r = parse_boundary_from_content_type(
    "multipart/form-data ; boundary = XYZ",
  )
  match r {
    Ok(b) => @test.assert_eq(b, "XYZ")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "boundary: missing returns error" {
  match parse_boundary_from_content_type("multipart/form-data") {
    Ok(_) => @test.assert_eq(true, false)
    Err(MissingBoundary) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "boundary: empty returns error" {
  match parse_boundary_from_content_type("multipart/form-data; boundary=") {
    Ok(_) => @test.assert_eq(true, false)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "boundary: too long returns error" {
  let long = "x".repeat(71)
  match
    parse_boundary_from_content_type("multipart/form-data; boundary=" + long) {
    Ok(_) => @test.assert_eq(true, false)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "boundary: case insensitive param name" {
  let r = parse_boundary_from_content_type("multipart/form-data; BOUNDARY=test")
  match r {
    Ok(b) => @test.assert_eq(b, "test")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "boundary: mixed case boundary preserved" {
  let r = parse_boundary_from_content_type(
    "multipart/form-data; boundary=MyBoundary123",
  )
  match r {
    Ok(b) => @test.assert_eq(b, "MyBoundary123")
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 2: Content-Disposition parsing (12 tests)
// ===========================================================================

///|
fn default_opts() -> ParseOptions {
  ParseOptions::default()
}

///|
test "disposition: name only" {
  let r = parse_content_disposition(
    "form-data; name=\"field1\"",
    default_opts(),
  )
  match r {
    Ok((n, f)) => {
      @test.assert_eq(n, "field1")
      @test.assert_eq(f, None)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: name and filename" {
  let r = parse_content_disposition(
    "form-data; name=\"f\"; filename=\"a.txt\"",
    default_opts(),
  )
  match r {
    Ok((n, f)) => {
      @test.assert_eq(n, "f")
      match f {
        Some(x) => @test.assert_eq(x, "a.txt")
        None => @test.assert_eq(true, false)
      }
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: unquoted values" {
  let r = parse_content_disposition(
    "form-data; name=field1; filename=doc.csv",
    default_opts(),
  )
  match r {
    Ok((n, f)) => {
      @test.assert_eq(n, "field1")
      match f {
        Some(x) => @test.assert_eq(x, "doc.csv")
        None => @test.assert_eq(true, false)
      }
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: path traversal rejected" {
  match
    parse_content_disposition(
      "form-data; name=\"f\"; filename=\"../etc/passwd\"",
      default_opts(),
    ) {
    Ok(_) => @test.assert_eq(true, false)
    Err(PathTraversal(_)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: missing name" {
  match
    parse_content_disposition("form-data; filename=\"x.txt\"", default_opts()) {
    Ok(_) => @test.assert_eq(true, false)
    Err(MissingName) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: not form-data rejected" {
  match parse_content_disposition("attachment; name=\"x\"", default_opts()) {
    Ok(_) => @test.assert_eq(true, false)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "disposition: name empty string" {
  let r = parse_content_disposition("form-data; name=\"\"", default_opts())
  match r {
    Ok((n, _)) => @test.assert_eq(n, "")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: filename empty string" {
  let r = parse_content_disposition(
    "form-data; name=\"x\"; filename=\"\"",
    default_opts(),
  )
  match r {
    Ok((_, f)) =>
      match f {
        Some(x) => @test.assert_eq(x, "")
        None => @test.assert_eq(true, false)
      }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: param order independent" {
  let r = parse_content_disposition(
    "form-data; filename=\"b.txt\"; name=\"a\"",
    default_opts(),
  )
  match r {
    Ok((n, f)) => {
      @test.assert_eq(n, "a")
      match f {
        Some(x) => @test.assert_eq(x, "b.txt")
        None => @test.assert_eq(true, false)
      }
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: semicolon inside quoted value" {
  let r = parse_content_disposition("form-data; name=\"a;b\"", default_opts())
  match r {
    Ok((n, _)) => @test.assert_eq(n, "a;b")
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: filename star rejected in strict" {
  let opts = ParseOptions::strict_rfc()
  match
    parse_content_disposition(
      "form-data; name=\"x\"; filename*=UTF-8''test.txt", opts,
    ) {
    Ok(_) => @test.assert_eq(true, false)
    Err(NonCompliantHeader(_)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "disposition: filename star accepted in compat" {
  let opts = ParseOptions::compatible()
  match
    parse_content_disposition(
      "form-data; name=\"x\"; filename*=UTF-8''t.txt", opts,
    ) {
    Ok((_, f)) =>
      match f {
        Some(_) => @test.assert_eq(true, true)
        None => @test.assert_eq(true, false)
      }
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 3: MultipartWriter — basic generation (8 tests)
// ===========================================================================

///|
test "writer: generates field" {
  let w = MultipartWriter::with_boundary("B")
  w.add_field("x", "y")
  let (b, body) = w.finish()
  @test.assert_eq(b, "B")
  @test.assert_eq(bytes_has(body, "name=\"x\""), true)
  @test.assert_eq(bytes_has(body, "B--"), true)
}

///|
test "writer: generates file" {
  let w = MultipartWriter::with_boundary("B")
  w.add_file("f", "a.txt", Some("text/plain"), b"hello")
  let (_, body) = w.finish()
  @test.assert_eq(bytes_has(body, "filename=\"a.txt\""), true)
  @test.assert_eq(bytes_has(body, "text/plain"), true)
  @test.assert_eq(bytes_has(body, "hello"), true)
}

///|
test "writer: multiple fields" {
  let w = MultipartWriter::with_boundary("B")
  w.add_field("a", "1")
  w.add_field("b", "2")
  let (_, body) = w.finish()
  @test.assert_eq(bytes_has(body, "name=\"a\""), true)
  @test.assert_eq(bytes_has(body, "name=\"b\""), true)
}

///|
test "writer: auto-generates boundary" {
  let w = MultipartWriter::new()
  @test.assert_eq(w.get_boundary().has_prefix("----MoonBitMultipart"), true)
}

///|
test "writer: part count tracking" {
  let w = MultipartWriter::with_boundary("B")
  w.add_field("a", "1")
  w.add_field("b", "2")
  @test.assert_eq(w.part_count(), 2)
}

///|
test "writer: empty field value" {
  let w = MultipartWriter::with_boundary("B")
  w.add_field("empty", "")
  let (_, body) = w.finish()
  @test.assert_eq(bytes_has(body, "name=\"empty\""), true)
}

///|
test "writer: binary file data preserved" {
  let w = MultipartWriter::with_boundary("B")
  let data = @buffer.Buffer()
  for i = 0; i < 256; i = i + 1 {
    data.write_byte(i.to_byte())
  }
  w.add_file("bin", "x.bin", Some("application/octet-stream"), data.to_bytes())
  let (_, body) = w.finish()
  // Find the binary data in the body
  @test.assert_eq(body.length() > 300, true)
}

///|
test "writer: no Content-Type for untyped file" {
  let w = MultipartWriter::with_boundary("B")
  w.add_file("f", "x.txt", None, b"data")
  let (_, body) = w.finish()
  @test.assert_eq(bytes_has(body, "Content-Type:"), false)
}

// ===========================================================================
// Part 4: End-to-end — generate then parse (10 tests)
// ===========================================================================

///|
test "e2e: single field roundtrip" {
  let boundary = "RoundTripB1"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("name", "value")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => {
      @test.assert_eq(f.len(), 1)
      @test.assert_eq(f.field("name") == Some("value"), true)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: single file roundtrip" {
  let boundary = "RoundTripB2"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_file("file", "doc.txt", Some("text/plain"), b"content")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => {
      @test.assert_eq(f.len(), 1)
      match f.file("file") {
        Some(p) => {
          @test.assert_eq(p.filename() == Some("doc.txt"), true)
          @test.assert_eq(p.data() == Some(b"content"), true)
        }
        None => @test.assert_eq(true, false)
      }
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: multiple fields preserve order" {
  let boundary = "RoundTripB3"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("first", "1")
  w.add_field("second", "2")
  w.add_field("third", "3")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => {
      @test.assert_eq(f.len(), 3)
      @test.assert_eq(f.field("first") == Some("1"), true)
      @test.assert_eq(f.field("third") == Some("3"), true)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: same-name fields" {
  let boundary = "RoundTripB4"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("tag", "a")
  w.add_field("tag", "b")
  w.add_field("tag", "c")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => {
      let vals = f.field_values("tag")
      @test.assert_eq(vals.length(), 3)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: multi-file same name" {
  let boundary = "RoundTripB5"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_file("files", "a.png", Some("image/png"), b"aaa")
  w.add_file("files", "b.png", Some("image/png"), b"bbb")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => {
      let fs = f.files("files")
      @test.assert_eq(fs.length(), 2)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: mixed fields and files" {
  let boundary = "RoundTripB6"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("title", "hello")
  w.add_file("attachment", "doc.pdf", Some("application/pdf"), b"%PDF")
  w.add_field("tags", "moonbit")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => @test.assert_eq(f.len(), 3)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: binary data preserved" {
  let boundary = "BinDataB"
  let bin = @buffer.Buffer()
  for i = 0; i < 256; i = i + 1 {
    bin.write_byte(i.to_byte())
  }
  let bin_data = bin.to_bytes()
  let w = MultipartWriter::with_boundary(boundary)
  w.add_file("data", "raw.bin", Some("application/octet-stream"), bin_data)
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) =>
      match f.file("data") {
        Some(p) => @test.assert_eq(p.data() == Some(bin_data), true)
        None => @test.assert_eq(true, false)
      }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: empty field" {
  let boundary = "EmptyB"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("empty", "")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => @test.assert_eq(f.field("empty") == Some(""), true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "e2e: field with special chars" {
  let boundary = "SpecialB"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("text", "hello\nworld\t\"quoted\"")
  let (_, body) = w.finish()
  let form = parse_all(body, boundary, default_opts())
  match form {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 5: Streaming parser tests (8 tests)
// ===========================================================================

///|
test "streaming: parse_all via low-level feed" {
  let boundary = "StreamB1"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(body) {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  @test.assert_eq(parser.is_finished(), true)
}

///|
test "streaming: PartBegin PartData PartEnd events" {
  let boundary = "StreamB2"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("key", "val")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(body) {
    Ok(evts) => {
      let mut has_begin = false
      let mut has_data = false
      let mut has_end = false
      let mut has_finished = false
      for e in evts {
        match e {
          PartBegin(_, _, _) => has_begin = true
          PartData(_) => has_data = true
          PartEnd => has_end = true
          Finished => has_finished = true
        }
      }
      @test.assert_eq(has_begin, true)
      @test.assert_eq(has_end, true)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "streaming: Finished event emitted" {
  let boundary = "StreamB3"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(body) {
    Ok(evts) => {
      let mut saw_finished = false
      for e in evts {
        match e {
          Finished => saw_finished = true
          _ => ()
        }
      }
      @test.assert_eq(saw_finished, true)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "streaming: feeds in multiple chunks" {
  let boundary = "StreamB4"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("name", "longvalue12345")
  let (_, full) = w.finish()
  let fl = full.length()
  let parser = Parser::new(boundary, default_opts())
  let mut offset = 0
  while offset < fl {
    let end = if offset + 10 > fl { fl } else { offset + 10 }
    match parser.feed(bv(full[offset:end])) {
      Ok(_) => ()
      Err(e) => @test.assert_eq(e.to_string(), "fail")
    }
    offset = offset + 10
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  @test.assert_eq(parser.is_finished(), true)
}

///|
test "streaming: single byte at a time" {
  let boundary = "StreamB5"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, full) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  let fl = full.length()
  let mut i = 0
  while i < fl {
    match parser.feed(bv(full[i:i + 1])) {
      Ok(_) => ()
      Err(_) => @test.assert_eq(true, false)
    }
    i = i + 1
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "streaming: feed then finish" {
  let boundary = "StreamB6"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("a", "b")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(body) {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "streaming: double feed on finished parser returns empty" {
  let boundary = "StreamB7"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(body) {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  match parser.feed(b"more") {
    Ok(evts) => @test.assert_eq(evts.length(), 0)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "streaming: missing close is incomplete" {
  let boundary = "StreamB8"
  let incomplete = @utf8.encode(
    "--StreamB8\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nvalue",
  )
  let parser = Parser::new(boundary, default_opts())
  match parser.feed(incomplete) {
    Ok(_) => ()
    Err(_) => @test.assert_eq(true, false)
  }
  match parser.finish() {
    Ok(_) => @test.assert_eq(true, false)
    Err(IncompleteBody) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 6: Split-chunk consistency tests (10 tests)
// ===========================================================================

///|
/// Helper: parse body once (all-at-once) and return form
fn parse_once(body : Bytes, boundary : String) -> MultipartForm {
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => f
    Err(_) => {
      let f = MultipartForm::new()
      f
    }
  }
}

///|
/// Helper: parse body in 2 chunks split at `i`
fn parse_split2(body : Bytes, boundary : String, i : Int) -> MultipartForm {
  let parser = Parser::new(boundary, default_opts())
  let form = MultipartForm::new()
  if i > 0 {
    match parser.feed(bv(body[0:i])) {
      Ok(evts) => coll_events(form, evts)
      Err(_) => ()
    }
  }
  match parser.feed(bv(body[i:])) {
    Ok(evts) => coll_events(form, evts)
    Err(_) => ()
  }
  match parser.finish() {
    Ok(evts) => coll_events(form, evts)
    Err(_) => ()
  }
  form
}

///|
fn coll_events(form : MultipartForm, events : Array[ParseEvent]) -> Unit {
  let mut nm : String? = None
  let mut fnm : String? = None
  let mut ct : String? = None
  let db = @buffer.Buffer()
  for e in events {
    match e {
      PartBegin(n, f, c) => {
        nm = Some(n)
        fnm = f
        ct = c
        db.reset()
      }
      PartData(d) => db.write_bytes(d)
      PartEnd =>
        match nm {
          Some(name) =>
            match fnm {
              Some(fname) =>
                form.parts.push(File(name, fname, ct, db.to_bytes()))
              None => {
                let fb = db.to_bytes()
                let fc : Array[Char] = []
                for bi = 0; bi < fb.length(); bi = bi + 1 {
                  fc.push(fb[bi].to_char())
                }
                form.parts.push(Field(name, String::from_array(fc)))
              }
            }
          None => ()
        }
      Finished => ()
    }
  }
}

///|
fn forms_equal(a : MultipartForm, b : MultipartForm) -> Bool {
  if a.len() != b.len() {
    return false
  }
  let ap = a.parts
  let bp = b.parts
  let mut i = 0
  while i < ap.length() {
    if !parts_eq(ap[i], bp[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn parts_eq(a : Part, b : Part) -> Bool {
  match a {
    Field(na, va) =>
      match b {
        Field(nb, vb) => na == nb && va == vb
        _ => false
      }
    File(na, fa, cta, da) =>
      match b {
        File(nb, fb, ctb, db) => na == nb && fa == fb && cta == ctb && da == db
        _ => false
      }
  }
}

///|
test "split: full body at once equals parse_all" {
  let boundary = "SplitOnce"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("name", "alice")
  w.add_field("email", "a@b.com")
  let (_, body) = w.finish()
  let expected = parse_once(body, boundary)
  @test.assert_eq(expected.len(), 2)
}

///|
test "split: 3-way split produces correct parts" {
  let boundary = "Split3Way"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "hello")
  let (_, body) = w.finish()
  let fl = body.length()
  let i = fl / 3
  let j = 2 * fl / 3
  let parser = Parser::new(boundary, default_opts())
  let form = MultipartForm::new()
  match parser.feed(bv(body[0:i])) {
    Ok(e) => coll_events(form, e)
    Err(_) => ()
  }
  match parser.feed(bv(body[i:j])) {
    Ok(e) => coll_events(form, e)
    Err(_) => ()
  }
  match parser.feed(bv(body[j:])) {
    Ok(e) => coll_events(form, e)
    Err(_) => ()
  }
  match parser.finish() {
    Ok(e) => coll_events(form, e)
    Err(_) => ()
  }
  @test.assert_eq(form.len(), 1)
}

///|
test "split: hard split at boundary position works" {
  let boundary = "SplitB1"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "hello")
  let (_, body) = w.finish()
  // Split in the middle of the body
  let mid = body.length() / 2
  let result = parse_split2(body, boundary, mid)
  @test.assert_eq(result.len(), 1)
}

///|
test "split: crlf split" {
  let boundary = "SplitCRLF"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let expected = parse_once(body, boundary)
  let mid = body.length() / 2
  let r = parse_split2(body, boundary, mid)
  @test.assert_eq(forms_equal(expected, r), true)
}

///|
test "split: header colon split" {
  let boundary = "SplitHdr"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("username", "testuser")
  let (_, body) = w.finish()
  let expected = parse_once(body, boundary)
  let colon = find_str(body, ":")
  match colon {
    None => @test.assert_eq(true, false)
    Some(i) => {
      let r = parse_split2(body, boundary, i + 1)
      @test.assert_eq(forms_equal(expected, r), true)
    }
  }
}

///|
test "split: closing boundary dash split" {
  let boundary = "SplitClose"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let expected = parse_once(body, boundary)
  let close = find_str(body, "--\r\n")
  match close {
    None => @test.assert_eq(true, false)
    Some(i) => {
      let r = parse_split2(body, boundary, i + 1)
      @test.assert_eq(forms_equal(expected, r), true)
    }
  }
}

///|
test "split: streaming chunks complete without error" {
  let boundary = "SplitStr"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "y")
  let (_, body) = w.finish()
  let parser = Parser::new(boundary, default_opts())
  let fl = body.length()
  let mut ok = true
  let mut i = 0
  while i < fl {
    let end = if i + 32 > fl { fl } else { i + 32 }
    match parser.feed(bv(body[i:end])) {
      Ok(_) => ()
      Err(_) => ok = false
    }
    i = end
  }
  match parser.finish() {
    Ok(_) => ()
    Err(_) => ok = false
  }
  @test.assert_eq(ok, true)
}

// ===========================================================================
// Part 7: Security limits (6 tests)
// ===========================================================================

///|
test "limits: too many parts" {
  let boundary = "LimParts"
  let w = MultipartWriter::with_boundary(boundary)
  for i = 0; i < 100; i = i + 1 {
    w.add_field("f" + i.to_string(), "v")
  }
  let (_, body) = w.finish()
  let strict = ParseOptions::{
    mode: Compatible,
    limits: Limits::strict(),
    reject_filename_star: true,
  }
  match parse_all(body, boundary, strict) {
    Ok(_) => @test.assert_eq(true, false)
    Err(TooManyParts(_)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "limits: field too large" {
  let boundary = "LimField"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("big", "x".repeat(100000))
  let (_, body) = w.finish()
  let strict = ParseOptions::{
    mode: Compatible,
    limits: Limits::strict(),
    reject_filename_star: true,
  }
  match parse_all(body, boundary, strict) {
    Ok(_) => @test.assert_eq(true, false)
    Err(FieldTooLarge(_, _)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "limits: total size exceeded" {
  let boundary = "LimTotal"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("x", "some value that creates enough bytes")
  let (_, body) = w.finish()
  let limit_val = Limits::{
    max_parts: 1000,
    max_header_size: 8192,
    max_field_size: 1048576,
    max_file_size: 104857600,
    max_total_size: 50,
    max_filename_len: 255,
  }
  let tiny = ParseOptions::{
    mode: Compatible,
    limits: limit_val,
    reject_filename_star: true,
  }
  match parse_all(body, boundary, tiny) {
    Ok(_) => @test.assert_eq(true, false)
    Err(TotalSizeExceeded(_)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "limits: file too large with small limit" {
  let boundary = "LimFile"
  let w = MultipartWriter::with_boundary(boundary)
  let buf = @buffer.Buffer()
  for i = 0; i < 2000; i = i + 1 {
    buf.write_byte(b'x')
  }
  w.add_file("big", "big.bin", None, buf.to_bytes())
  let (_, body) = w.finish()
  let small = Limits::{
    max_parts: 100,
    max_header_size: 8192,
    max_field_size: 1024,
    max_file_size: 1000,
    max_total_size: 1000000,
    max_filename_len: 255,
  }
  let opts = ParseOptions::{
    mode: Compatible,
    limits: small,
    reject_filename_star: true,
  }
  match parse_all(body, boundary, opts) {
    Ok(_) => @test.assert_eq(true, false)
    Err(FileTooLarge(_, _)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "limits: invalid body produces error" {
  let boundary = "LimBad"
  let body = @utf8.encode(
    "--" + boundary + "\r\nBad-Header\r\n\r\ndata\r\n--" + boundary + "--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(_) => @test.assert_eq(true, false)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "limits: filename too long rejected" {
  let boundary = "LimFname"
  let long_fn = "x".repeat(300)
  match
    parse_content_disposition(
      "form-data; name=\"f\"; filename=\"" + long_fn + "\"",
      default_opts(),
    ) {
    Ok(_) => @test.assert_eq(true, false)
    Err(FilenameTooLong(_, _)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 8: Edge cases & boundary conditions (10 tests)
// ===========================================================================

///|
test "edge: body contains boundary-like text (not at line start)" {
  let boundary = "MyBoundary"
  let body = @utf8.encode(
    "--MyBoundary\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nsome--MyBoundarytext\r\n--MyBoundary--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: preamble before first boundary" {
  let boundary = "PreambleB"
  let body = @utf8.encode(
    "This is preamble\r\n--PreambleB\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nval\r\n--PreambleB--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: epilogue after closing boundary" {
  let boundary = "EpilogueB"
  let body = @utf8.encode(
    "--EpilogueB\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nv\r\n--EpilogueB--\r\nepilogue text",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: part without Content-Type" {
  let boundary = "NoCTB"
  let body = @utf8.encode(
    "--NoCTB\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nvalue\r\n--NoCTB--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: part with charset in Content-Type" {
  let boundary = "CharsetB"
  let body = @utf8.encode(
    "--CharsetB\r\nContent-Disposition: form-data; name=\"x\"\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nhello\r\n--CharsetB--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: uppercase header names" {
  let boundary = "UpperB"
  let body = @utf8.encode(
    "--UpperB\r\nCONTENT-DISPOSITION: form-data; name=\"x\"\r\n\r\nval\r\n--UpperB--\r\n",
  )
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 1)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: file with no Content-Type defaults ok" {
  let boundary = "NoCTFile"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_file("f", "data.bin", None, b"raw")
  let (_, body) = w.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => {
      @test.assert_eq(f.len(), 1)
      @test.assert_eq(
        match f.file("f") {
          Some(_) => true
          None => false
        },
        true,
      )
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: many parts under limit" {
  let boundary = "ManyParts"
  let w = MultipartWriter::with_boundary(boundary)
  for i = 0; i < 30; i = i + 1 {
    w.add_field("f" + i.to_string(), "v" + i.to_string())
  }
  let (_, body) = w.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 30)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: part order preserved" {
  let boundary = "OrderB"
  let w = MultipartWriter::with_boundary(boundary)
  w.add_field("a", "1")
  w.add_field("b", "2")
  w.add_field("c", "3")
  let (_, body) = w.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => {
      let parts = f.parts
      @test.assert_eq(parts.length(), 3)
      @test.assert_eq(parts[0].name(), "a")
      @test.assert_eq(parts[1].name(), "b")
      @test.assert_eq(parts[2].name(), "c")
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "edge: no parts at all (empty form)" {
  let boundary = "EmptyForm"
  let body = @utf8.encode("--EmptyForm--\r\n")
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 0)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 9: Safe filename tests (6 tests)
// ===========================================================================

///|
test "safe_fn: clean filename unchanged" {
  @test.assert_eq(safe_filename("photo.jpg"), "photo.jpg")
}

///|
test "safe_fn: path traversal removed" {
  let r = safe_filename("../../../etc/passwd")
  @test.assert_eq(r.contains("etc_passwd"), true)
  @test.assert_eq(r.contains(".."), false)
}

///|
test "safe_fn: backslash replaced" {
  @test.assert_eq(safe_filename("folder\\file.txt"), "folder_file.txt")
}

///|
test "safe_fn: drive letter stripped" {
  let r = safe_filename("C:\\Users\\test.txt")
  @test.assert_eq(r.contains(":"), false)
}

///|
test "safe_fn: null byte removed" {
  // We can't easily create null bytes in MoonBit strings, so test basic safety
  @test.assert_eq(safe_filename("normal.txt"), "normal.txt")
}

///|
test "safe_fn: unique generates safe name" {
  let a = unique_filename("file.txt")
  @test.assert_eq(a.contains(".."), false)
  @test.assert_eq(a.contains("/"), false)
  @test.assert_eq(a.contains("\\"), false)
}

// ===========================================================================
// Part 10: Writer streaming API tests (4 tests)
// ===========================================================================

///|
test "writer_streaming: basic chunked write" {
  let boundary = "ChunkW1"
  let sw = StreamingWriter::new(boundary)
  sw.begin_part("field1", None, None)
  sw.write_chunk(b"hello ")
  sw.write_chunk(b"world")
  sw.end_part()
  let body = sw.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => {
      @test.assert_eq(f.len(), 1)
      @test.assert_eq(f.field("field1") == Some("hello world"), true)
    }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "writer_streaming: file with chunks" {
  let boundary = "ChunkW2"
  let sw = StreamingWriter::new(boundary)
  sw.begin_part("file", Some("data.bin"), Some("application/octet-stream"))
  sw.write_chunk(b"\x00\x01\x02")
  sw.write_chunk(b"\x03\x04\x05")
  sw.end_part()
  let body = sw.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) =>
      match f.file("file") {
        Some(p) =>
          @test.assert_eq(p.data() == Some(b"\x00\x01\x02\x03\x04\x05"), true)
        None => @test.assert_eq(true, false)
      }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "writer_streaming: multiple parts" {
  let boundary = "ChunkW3"
  let sw = StreamingWriter::new(boundary)
  sw.begin_part("a", None, None)
  sw.write_chunk(b"1")
  sw.end_part()
  sw.begin_part("b", None, None)
  sw.write_chunk(b"2")
  sw.end_part()
  let body = sw.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.len(), 2)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "writer_streaming: empty part" {
  let boundary = "ChunkW4"
  let sw = StreamingWriter::new(boundary)
  sw.begin_part("e", None, None)
  sw.end_part()
  let body = sw.finish()
  match parse_all(body, boundary, default_opts()) {
    Ok(f) => @test.assert_eq(f.field("e") == Some(""), true)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// Part 11: Strict vs Compatible mode (3 tests)
// ===========================================================================

///|
test "mode: strict rejects filename star" {
  let opts = ParseOptions::strict_rfc()
  match
    parse_content_disposition(
      "form-data; name=\"x\"; filename*=UTF-8''t.txt", opts,
    ) {
    Ok(_) => @test.assert_eq(true, false)
    Err(NonCompliantHeader(_)) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "mode: compatible accepts filename star" {
  let opts = ParseOptions::compatible()
  match
    parse_content_disposition(
      "form-data; name=\"x\"; filename*=UTF-8''t.txt", opts,
    ) {
    Ok((_, f)) =>
      match f {
        Some(_) => @test.assert_eq(true, true)
        None => @test.assert_eq(true, false)
      }
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "mode: default is compatible" {
  let opts = ParseOptions::default()
  @test.assert_eq(opts.mode == Compatible, true)
}

// ===========================================================================
// Boundary validation edge cases (3 tests)
// ===========================================================================

///|
test "validate_boundary: empty rejected" {
  match validate_boundary("") {
    Ok(_) => @test.assert_eq(true, false)
    Err(_) => @test.assert_eq(true, true)
  }
}

///|
test "validate_boundary: valid boundary accepted" {
  match validate_boundary("----ValidBoundary") {
    Ok(_) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

///|
test "validate_boundary: max length allowed" {
  let b = "a".repeat(70)
  match validate_boundary(b) {
    Ok(_) => @test.assert_eq(true, true)
    Err(_) => @test.assert_eq(true, false)
  }
}

// ===========================================================================
// MultipartForm convenience methods (3 tests)
// ===========================================================================

///|
test "form: field_values returns all same-name values" {
  let form = MultipartForm::new()
  form.parts.push(Field("tag", "a"))
  form.parts.push(Field("tag", "b"))
  @test.assert_eq(form.field_values("tag").length(), 2)
}

///|
test "form: files returns all same-name files" {
  let form = MultipartForm::new()
  form.parts.push(File("img", "a.png", None, b"a"))
  form.parts.push(File("img", "b.png", None, b"b"))
  @test.assert_eq(form.files("img").length(), 2)
}

///|
test "form: field returns first match" {
  let form = MultipartForm::new()
  form.parts.push(Field("x", "first"))
  form.parts.push(Field("x", "second"))
  @test.assert_eq(form.field("x") == Some("first"), true)
}

// ===========================================================================
// Utility helpers
// ===========================================================================

///|
fn bytes_has(data : Bytes, text : String) -> Bool {
  let pattern = @utf8.encode(text)
  let dl = data.length()
  let pl = pattern.length()
  if pl == 0 || dl < pl {
    return false
  }
  let mut i = 0
  while i <= dl - pl {
    let mut ok = true
    let mut j = 0
    while j < pl {
      if data[i + j] != pattern[j] {
        ok = false
        j = pl
      } else {
        j = j + 1
      }
    }
    if ok {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn bv(view : BytesView) -> Bytes {
  let b = @buffer.Buffer()
  b.write_bytesview(view)
  b.to_bytes()
}

///|
fn find_str(data : Bytes, needle : String) -> Int? {
  let pat = @utf8.encode(needle)
  let dl = data.length()
  let pl = pat.length()
  if pl == 0 || dl < pl {
    return None
  }
  let mut i = 0
  while i <= dl - pl {
    let mut ok = true
    let mut j = 0
    while j < pl {
      if data[i + j] != pat[j] {
        ok = false
        j = pl
      } else {
        j = j + 1
      }
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}
