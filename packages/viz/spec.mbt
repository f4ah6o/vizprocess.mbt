///|
pub enum Mark {
  BAR
  LINE
} derive(Eq, Show)

///|
pub fn Mark::name(self : Mark) -> String {
  match self {
    BAR => "bar"
    LINE => "line"
  }
}

///|
pub struct Channel {
  field : String
} derive(Eq, Show)

///|
pub struct Encoding {
  x : Channel?
  y : Channel?
} derive(Eq, Show)

///|
pub struct ChartConfig {
  width : Int
  height : Int
} derive(Eq, Show)

///|
pub fn ChartConfig::default() -> ChartConfig {
  { width: 480, height: 240 }
}

///|
pub struct ChartSpec {
  id : String
  mark : Mark
  encoding : Encoding
  config : ChartConfig
} derive(Eq, Show)
