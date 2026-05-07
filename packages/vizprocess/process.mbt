///|
pub(all) enum ExecutionStatus {
  EsSuccess
  EsFailed
} derive(Eq, Show)

///|
/// One artifact's resolved content (in-memory). `path` is the stable id
/// from the manifest; for `OtMemory` artifacts it is the artifact id.
pub(all) struct ArtifactResult {
  id : String
  kind : ArtifactKind
  content : String
} derive(Eq, Show)

///|
/// The full result of running a `VizProcess`. Diagnostics aggregate every
/// pipe / viz / process diagnostic encountered, sorted deterministically.
pub(all) struct ProcessExecution {
  process_id : String
  status : ExecutionStatus
  diagnostics : Array[Diagnostic]
  artifacts : Array[ArtifactResult]
} derive(Eq, Show)

///|
/// Run the manifest end-to-end:
/// 1. each `DatasetNode.pipeline` is executed against its `source`,
///    yielding a `pipe.Dataset` indexed by `dataset_id`;
/// 2. each `ChartNode` looks up its dataset, adapts to `VizDataset`, and
///    is compiled into a `RenderModel`;
/// 3. each `ArtifactNode` resolves its chart and renders to the requested
///    format.
///
/// Failures in step 1 or 2 produce diagnostics but execution continues so
/// the report is comprehensive.
pub fn run_process(p : VizProcess) -> ProcessExecution {
  let diagnostics : Array[Diagnostic] = []
  let datasets : Map[String, @pipe.Dataset] = Map::new()
  for node in p.datasets {
    let result = @pipe.run_pipeline(node.source, node.pipeline)
    for d in result.diagnostics {
      diagnostics.push(Diagnostic::from_pipe(d))
    }
    if result.diagnostics.length() == 0 {
      datasets[node.id] = result.dataset
    } else {
      diagnostics.push(
        Diagnostic::process_error(
          code_pipeline_failed,
          "datasets[" + node.id + "]",
          "pipeline produced " +
          result.diagnostics.length().to_string() +
          " diagnostic(s)",
        ),
      )
    }
  }
  let render_models : Map[String, @viz.RenderModel] = Map::new()
  for node in p.charts {
    match datasets.get(node.dataset_id) {
      None =>
        diagnostics.push(
          Diagnostic::process_error(
            code_unknown_dataset,
            "charts[" + node.id + "]",
            "dataset '" + node.dataset_id + "' was not produced",
          ),
        )
      Some(d) => {
        let viz_dataset = dataset_to_viz(d)
        let result = @viz.compile_chart(node.chart, viz_dataset)
        for vd in result.diagnostics {
          diagnostics.push(Diagnostic::from_viz(vd))
        }
        if result.diagnostics.length() == 0 {
          render_models[node.id] = result.model
        } else {
          diagnostics.push(
            Diagnostic::process_error(
              code_chart_compile_failed,
              "charts[" + node.id + "]",
              "compile_chart produced " +
              result.diagnostics.length().to_string() +
              " diagnostic(s)",
            ),
          )
        }
      }
    }
  }
  let chart_datasets : Map[String, String] = Map::new()
  for node in p.charts {
    chart_datasets[node.id] = node.dataset_id
  }
  let artifacts : Array[ArtifactResult] = []
  for node in p.artifacts {
    match render_models.get(node.chart_id) {
      None =>
        diagnostics.push(
          Diagnostic::process_error(
            code_unknown_chart,
            "artifacts[" + node.id + "]",
            "chart '" + node.chart_id + "' was not compiled",
          ),
        )
      Some(model) => {
        let content = match node.kind {
          AkSvg => @viz.render_svg(model)
          AkRenderModelJson => @viz.render_json(model)
          AkDatasetJson => {
            let dataset_id = chart_datasets.get(node.chart_id).unwrap()
            @pipe.dataset_to_json(datasets.get(dataset_id).unwrap())
          }
        }
        artifacts.push({ id: node.id, kind: node.kind, content })
      }
    }
  }
  sort_diagnostics(diagnostics)
  let mut has_error = false
  for d in diagnostics {
    if d.severity == ERROR {
      has_error = true
      break
    }
  }
  let status = if has_error { EsFailed } else { EsSuccess }
  { process_id: p.id, status, diagnostics, artifacts }
}

///|
/// Stable sort by `(source, code, target)`.
fn sort_diagnostics(diags : Array[Diagnostic]) -> Unit {
  let n = diags.length()
  for i in 1..<n {
    let cur = diags[i]
    let mut j = i
    while j > 0 {
      let prev = diags[j - 1]
      let cmp = compare_diagnostic(prev, cur)
      if cmp <= 0 {
        break
      }
      diags[j] = prev
      j = j - 1
    }
    diags[j] = cur
  }
}

///|
fn compare_diagnostic(a : Diagnostic, b : Diagnostic) -> Int {
  if a.source < b.source {
    return -1
  }
  if a.source > b.source {
    return 1
  }
  if a.code < b.code {
    return -1
  }
  if a.code > b.code {
    return 1
  }
  if a.target < b.target {
    return -1
  }
  if a.target > b.target {
    return 1
  }
  0
}
