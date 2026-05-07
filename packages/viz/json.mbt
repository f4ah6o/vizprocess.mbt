///|
/// Render a `RenderModel` as deterministic JSON with alphabetically-sorted
/// object keys. The shape is:
///
/// ```json
/// {
///   "height": 240,
///   "id": "...",
///   "layers": [
///     {"kind": "rect", "marks": [...]},
///     {"kind": "line", "points": [...]}
///   ],
///   "width": 480
/// }
/// ```
pub fn render_json(model : RenderModel) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"height\":")
  buf.write_string(model.height.to_string())
  buf.write_string(",\"id\":\"")
  write_json_escaped(buf, model.id)
  buf.write_string("\",\"layers\":[")
  for i in 0..<model.layers.length() {
    if i > 0 {
      buf.write_char(',')
    }
    write_layer(buf, model.layers[i])
  }
  buf.write_string("],\"width\":")
  buf.write_string(model.width.to_string())
  buf.write_char('}')
  buf.to_string()
}

///|
fn write_layer(buf : StringBuilder, layer : RenderLayer) -> Unit {
  match layer {
    RectLayer(marks) => {
      buf.write_string("{\"kind\":\"rect\",\"marks\":[")
      for i in 0..<marks.length() {
        if i > 0 {
          buf.write_char(',')
        }
        let m = marks[i]
        buf.write_string("{\"height\":")
        buf.write_string(m.height.to_string())
        buf.write_string(",\"label\":\"")
        write_json_escaped(buf, m.label)
        buf.write_string("\",\"width\":")
        buf.write_string(m.width.to_string())
        buf.write_string(",\"x\":")
        buf.write_string(m.x.to_string())
        buf.write_string(",\"y\":")
        buf.write_string(m.y.to_string())
        buf.write_char('}')
      }
      buf.write_string("]}")
    }
    LineLayer(points) => {
      buf.write_string("{\"kind\":\"line\",\"points\":[")
      for i in 0..<points.length() {
        if i > 0 {
          buf.write_char(',')
        }
        let p = points[i]
        buf.write_string("{\"label\":\"")
        write_json_escaped(buf, p.label)
        buf.write_string("\",\"x\":")
        buf.write_string(p.x.to_string())
        buf.write_string(",\"y\":")
        buf.write_string(p.y.to_string())
        buf.write_char('}')
      }
      buf.write_string("]}")
    }
  }
}

///|
fn write_json_escaped(buf : StringBuilder, s : String) -> Unit {
  for ch in s {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
}
