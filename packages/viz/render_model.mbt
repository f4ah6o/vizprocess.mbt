///|
/// Backend-independent, pixel-accurate model produced by `compile_chart`.
/// All coordinates are integers so `RenderModel` JSON is byte-stable.
pub(all) struct RenderModel {
  id : String
  width : Int32
  height : Int32
  layers : Array[RenderLayer]
} derive(Eq, Show)

///|
pub(all) enum RenderLayer {
  RectLayer(Array[RectMark])
  LineLayer(Array[LinePoint])
} derive(Eq, Show)

///|
/// Top-left x/y plus width/height in pixels. The `label` is a stable id
/// derived from the encoding x category, used by renderers as the SVG
/// element id.
pub(all) struct RectMark {
  label : String
  x : Int32
  y : Int32
  width : Int32
  height : Int32
} derive(Eq, Show)

///|
pub(all) struct LinePoint {
  label : String
  x : Int32
  y : Int32
} derive(Eq, Show)
