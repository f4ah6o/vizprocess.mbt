///|
/// Adapt a `pipe.Dataset` (column-oriented) to a `viz.VizDataset`
/// (row-oriented). `pipe.VNull` becomes `viz.VsString("")`; M4 fixtures do
/// not exercise nulls.
pub fn dataset_to_viz(d : @pipe.Dataset) -> @viz.VizDataset {
  let fields : Array[String] = []
  for f in d.schema.fields {
    fields.push(f.name)
  }
  let rows : Array[Array[@viz.VizValue]] = []
  for i in 0..<d.n_rows {
    let row : Array[@viz.VizValue] = []
    for f in d.schema.fields {
      let v = d.columns.get(f.name).unwrap()[i]
      let vv : @viz.VizValue = match v {
        @pipe.VString(s) => @viz.VsString(s)
        @pipe.VInt(n) => @viz.VsInt(n)
        @pipe.VNull => @viz.VsString("")
      }
      row.push(vv)
    }
    rows.push(row)
  }
  { fields, rows }
}
