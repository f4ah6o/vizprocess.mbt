///|
/// Render a `RenderModel` as a deterministic single-line SVG document.
/// Output format (byte-stable across runs):
///
/// ```svg
/// <svg xmlns="http://www.w3.org/2000/svg" width="W" height="H">
///   <g><rect x="..." y="..." width="..." height="..."/>...</g>
///   <g><polyline points="x0,y0 x1,y1 ..." fill="none" stroke="black"/></g>
/// </svg>
/// ```
///
/// (rendered without indentation or newlines). Axes, legends, and
/// per-mark styling arrive in later milestones.
pub fn render_svg(model : RenderModel) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"")
  buf.write_string(model.width.to_string())
  buf.write_string("\" height=\"")
  buf.write_string(model.height.to_string())
  buf.write_string("\">")
  for layer in model.layers {
    write_svg_layer(buf, layer)
  }
  buf.write_string("</svg>")
  buf.to_string()
}

///|
fn write_svg_layer(buf : StringBuilder, layer : RenderLayer) -> Unit {
  match layer {
    RectLayer(marks) => {
      buf.write_string("<g>")
      for m in marks {
        buf.write_string("<rect x=\"")
        buf.write_string(m.x.to_string())
        buf.write_string("\" y=\"")
        buf.write_string(m.y.to_string())
        buf.write_string("\" width=\"")
        buf.write_string(m.width.to_string())
        buf.write_string("\" height=\"")
        buf.write_string(m.height.to_string())
        buf.write_string("\"/>")
      }
      buf.write_string("</g>")
    }
    LineLayer(points) => {
      buf.write_string("<g><polyline points=\"")
      for i in 0..<points.length() {
        if i > 0 {
          buf.write_char(' ')
        }
        let p = points[i]
        buf.write_string(p.x.to_string())
        buf.write_char(',')
        buf.write_string(p.y.to_string())
      }
      buf.write_string("\" fill=\"none\" stroke=\"black\"/></g>")
    }
  }
}
