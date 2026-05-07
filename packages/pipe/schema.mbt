///|
/// Logical data types. M1 supports the integer and string subset; richer
/// types (Float, Date, etc.) arrive once deterministic formatting is in
/// place.
pub enum DataType {
  TString
  TInt
} derive(Eq, Show)

///|
pub fn DataType::name(self : DataType) -> String {
  match self {
    TString => "string"
    TInt => "int"
  }
}

///|
/// A single value in a row. `VNull` is used when a column is nullable; M1
/// fixtures do not produce nulls.
pub enum Value {
  VString(String)
  VInt(Int64)
  VNull
} derive(Eq, Show)

///|
pub fn Value::data_type(self : Value) -> DataType? {
  match self {
    VString(_) => Some(TString)
    VInt(_) => Some(TInt)
    VNull => None
  }
}

///|
pub struct FieldSchema {
  name : String
  dtype : DataType
} derive(Eq, Show)

///|
pub struct DataSchema {
  fields : Array[FieldSchema]
} derive(Eq, Show)

///|
pub fn DataSchema::find(self : DataSchema, name : String) -> FieldSchema? {
  for f in self.fields {
    if f.name == name {
      return Some(f)
    }
  }
  None
}
