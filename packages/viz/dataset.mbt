///|
/// `viz` consumes datasets through this row-oriented value, so it stays
/// independent of `pipe`'s column-oriented `Dataset`. M4's `vizprocess`
/// layer adapts `pipe.Dataset` to `VizDataset`.
pub enum VizValue {
  VsString(String)
  VsInt(Int64)
} derive(Eq, Show)

///|
pub fn VizValue::as_string(self : VizValue) -> String? {
  match self {
    VsString(s) => Some(s)
    _ => None
  }
}

///|
pub fn VizValue::as_int(self : VizValue) -> Int64? {
  match self {
    VsInt(n) => Some(n)
    _ => None
  }
}

///|
pub struct VizDataset {
  fields : Array[String]
  rows : Array[Array[VizValue]]
} derive(Eq, Show)

///|
pub fn VizDataset::field_index(self : VizDataset, name : String) -> Int {
  for i in 0..<self.fields.length() {
    if self.fields[i] == name {
      return i
    }
  }
  -1
}
