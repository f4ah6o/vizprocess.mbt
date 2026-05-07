///|
pub(all) struct VizResult {
  spec : ChartSpec
  model : RenderModel
  diagnostics : Array[Diagnostic]
} derive(Eq, Show)

///|
/// M2 layout: a fixed 40px gutter on the left and 20px on the other three
/// sides. The plot area fills the rest.
let plot_pad_left : Int = 40

///|
let plot_pad_top : Int = 20

///|
let plot_pad_right : Int = 20

///|
let plot_pad_bottom : Int = 20

///|
/// Validate a chart against a dataset without producing a render model.
pub fn validate_chart(
  spec : ChartSpec,
  dataset : VizDataset,
) -> Array[Diagnostic] {
  let diags : Array[Diagnostic] = []
  match spec.encoding.x {
    None =>
      diags.push(
        Diagnostic::error(
          code_invalid_encoding, "encoding.x", "x channel is required",
        ),
      )
    Some(c) =>
      if dataset.field_index(c.field) < 0 {
        diags.push(
          Diagnostic::error(
            code_field_not_found,
            "encoding.x",
            "field '" + c.field + "' not in dataset",
          ),
        )
      }
  }
  match spec.encoding.y {
    None =>
      diags.push(
        Diagnostic::error(
          code_invalid_encoding, "encoding.y", "y channel is required",
        ),
      )
    Some(c) =>
      if dataset.field_index(c.field) < 0 {
        diags.push(
          Diagnostic::error(
            code_field_not_found,
            "encoding.y",
            "field '" + c.field + "' not in dataset",
          ),
        )
      }
  }
  if spec.config.width <= plot_pad_left + plot_pad_right ||
    spec.config.height <= plot_pad_top + plot_pad_bottom {
    diags.push(
      Diagnostic::error(
        code_invalid_encoding, "config", "width and height must leave room for padding",
      ),
    )
  }
  diags
}

///|
/// Lower a `ChartSpec + VizDataset` to a `RenderModel`. Returns the same
/// `spec` echoed back for downstream consumers, the model, and any
/// diagnostics. If validation fails the model is returned empty (no
/// layers) so callers can still serialize it.
pub fn compile_chart(spec : ChartSpec, dataset : VizDataset) -> VizResult {
  let diags = validate_chart(spec, dataset)
  let empty_model : RenderModel = {
    id: spec.id,
    width: spec.config.width,
    height: spec.config.height,
    layers: [],
  }
  if diags.length() > 0 {
    return { spec, model: empty_model, diagnostics: diags }
  }
  let x_channel = spec.encoding.x.unwrap()
  let y_channel = spec.encoding.y.unwrap()
  let x_idx = dataset.field_index(x_channel.field)
  let y_idx = dataset.field_index(y_channel.field)
  let x_categories : Array[String] = []
  let y_values : Array[Int64] = []
  for row in dataset.rows {
    let xv = match row[x_idx] {
      VsString(s) => s
      VsInt(n) => n.to_string()
    }
    let yv = match row[y_idx] {
      VsInt(n) => n
      VsString(_) => 0L
    }
    x_categories.push(xv)
    y_values.push(yv)
  }
  let plot_x0 = plot_pad_left
  let plot_y0 = plot_pad_top
  let plot_w = spec.config.width - plot_pad_left - plot_pad_right
  let plot_h = spec.config.height - plot_pad_top - plot_pad_bottom
  let n = x_categories.length()
  let mut y_max = 0L
  for v in y_values {
    if v > y_max {
      y_max = v
    }
  }
  if y_max == 0L {
    y_max = 1L
  }
  let layer = match spec.mark {
    BAR => {
      let band_step = if n > 0 { plot_w / n } else { 0 }
      let band_pad = if band_step > 4 { 2 } else { 0 }
      let bar_w = band_step - band_pad * 2
      let bars : Array[RectMark] = []
      for i in 0..<n {
        let x = plot_x0 + i * band_step + band_pad
        let h = scale_linear(y_values[i], y_max, plot_h)
        let y = plot_y0 + plot_h - h
        bars.push({ label: x_categories[i], x, y, width: bar_w, height: h })
      }
      RectLayer(bars)
    }
    LINE => {
      let band_step = if n > 1 { plot_w / (n - 1) } else { 0 }
      let points : Array[LinePoint] = []
      for i in 0..<n {
        let x = plot_x0 + i * band_step
        let h = scale_linear(y_values[i], y_max, plot_h)
        let y = plot_y0 + plot_h - h
        points.push({ label: x_categories[i], x, y })
      }
      LineLayer(points)
    }
  }
  {
    spec,
    model: {
      id: spec.id,
      width: spec.config.width,
      height: spec.config.height,
      layers: [layer],
    },
    diagnostics: diags,
  }
}

///|
/// Round (value / domain * range) to the nearest integer, with ties going
/// up. Domain is assumed positive; value is clamped at zero.
fn scale_linear(value : Int64, domain : Int64, range : Int) -> Int {
  if value <= 0L || domain <= 0L {
    return 0
  }
  let v = value
  let d = domain
  let r = range.to_int64()
  let scaled = v * r * 2L / d
  let rounded = (scaled + 1L) / 2L
  rounded.to_int()
}
