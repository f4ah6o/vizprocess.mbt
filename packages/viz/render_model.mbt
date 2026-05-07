///|
/// Backend-independent, pixel-accurate model produced by `compile_chart`.
/// All coordinates are integers so `RenderModel` JSON is byte-stable.
pub struct RenderModel {
  id : String
  width : Int
  height : Int
  layers : Array[RenderLayer]
} derive(Eq, Show)

///|
pub enum RenderLayer {
  RectLayer(Array[RectMark])
  LineLayer(Array[LinePoint])
} derive(Eq, Show)

///|
/// Top-left x/y plus width/height in pixels. The `label` is a stable id
/// derived from the encoding x category, used by renderers as the SVG
/// element id.
pub struct RectMark {
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Show)

///|
pub struct LinePoint {
  label : String
  x : Int
  y : Int
} derive(Eq, Show)
