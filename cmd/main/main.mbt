///|
/// moon-multipart local roundtrip demo.
/// Generate a multipart body → parse it back → print results.
/// Run: `moon run cmd/main`
fn main {
  let w = @lib.MultipartWriter::with_boundary("DemoBoundary")
  w.add_field("title", "Hello moon-multipart")
  w.add_field("tags", "moonbit multipart rfc7578")
  w.add_file(
    "readme",
    "README.md",
    Some("text/markdown"),
    b"# moon-multipart\nA streaming multipart parser for MoonBit.",
  )
  let (boundary, body) = w.finish()

  match @lib.parse_all(body, boundary, @lib.ParseOptions::default()) {
    Ok(form) => {
      println(
        "Generated " +
        body.length().to_string() +
        " bytes, parsed " +
        form.len().to_string() +
        " parts",
      )
      for i = 0; i < form.parts.length(); i = i + 1 {
        match form.parts[i] {
          @lib.Field(name, value) =>
            println("  field \"" + name + "\" = \"" + value + "\"")
          @lib.File(name, filename, ct, data) => {
            let ct_str = match ct {
              Some(c) => c
              None => "(none)"
            }
            println(
              "  file \"" +
              name +
              "\" filename=\"" +
              filename +
              "\" type=" +
              ct_str +
              " size=" +
              data.length().to_string(),
            )
          }
        }
      }
    }
    Err(e) => println("Parse error: " + e.to_string())
  }
}
