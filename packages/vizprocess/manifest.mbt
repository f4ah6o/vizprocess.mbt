///|
/// Output format for a generated artifact. M4 implements all three.
pub(all) enum ArtifactKind {
  AkSvg
  AkRenderModelJson
  AkDatasetJson
} derive(Eq, Show)

///|
/// Where an artifact's content goes. M4 only retains artifacts in memory;
/// file / stdout / opfs targets arrive in M5+.
pub(all) enum OutputTarget {
  OtMemory
} derive(Eq, Show)

///|
/// A dataset to materialize. `source` is a pre-built `pipe.Dataset` (CSV
/// loading is a CLI / loader concern, not a manifest one in M4); the
/// pipeline runs against it.
pub(all) struct DatasetNode {
  id : String
  source : @pipe.Dataset
  pipeline : @pipe.Pipeline
}

///|
pub(all) struct ChartNode {
  id : String
  dataset_id : String
  chart : @viz.ChartSpec
}

///|
pub(all) struct ArtifactNode {
  id : String
  kind : ArtifactKind
  chart_id : String
  output : OutputTarget
}

///|
pub(all) struct VizProcess {
  id : String
  datasets : Array[DatasetNode]
  charts : Array[ChartNode]
  artifacts : Array[ArtifactNode]
}
