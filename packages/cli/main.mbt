///|
fn main {
  let args = @sys.get_cli_args()
  let code = run(args)
  @sys.exit(code)
}

///|
/// Pure dispatch from argv to an exit code. Splitting it out from `main`
/// keeps the side-effecting layer thin.
fn run(args : Array[String]) -> Int {
  if args.length() < 2 {
    print_usage()
    return exit_invalid_input
  }
  match args[1] {
    "process-run" => cmd_process_run(args)
    "version" => {
      println("vizprocess 0.1.0")
      exit_ok
    }
    "help" | "--help" | "-h" => {
      print_usage()
      exit_ok
    }
    cmd => {
      println("error: unknown subcommand '" + cmd + "'")
      print_usage()
      exit_invalid_input
    }
  }
}

///|
fn print_usage() -> Unit {
  println("vizprocess - reproducible data visualization process runner")
  println("")
  println("Usage:")
  println("  vizprocess process-run <manifest.json> <output-dir>")
  println("  vizprocess version")
  println("  vizprocess help")
  println("")
  println(
    "<manifest.json> is a process manifest (see fixtures/specs/*.process.json).",
  )
  println(
    "csv-file source paths are resolved relative to the manifest's directory.",
  )
}

///|
fn cmd_process_run(args : Array[String]) -> Int {
  if args.length() != 4 {
    println("error: process-run requires <manifest.json> <output-dir>")
    return exit_invalid_input
  }
  let manifest_path = args[2]
  let out_dir = args[3]
  let manifest_dir = dirname(manifest_path)
  let manifest_text = match read_file(manifest_path) {
    Ok(s) => s
    Err(e) => {
      println("error: cannot read manifest at '" + manifest_path + "': " + e)
      return exit_source_read_failed
    }
  }
  let csv_reader : (String) -> Result[String, String] = fn(rel) {
    let abs = if manifest_dir == "" { rel } else { manifest_dir + "/" + rel }
    read_file(abs)
  }
  let process = match
    @vizprocess.build_process_from_json(manifest_text, csv_reader) {
    Ok(p) => p
    Err(e) => {
      println("error: invalid manifest: " + e)
      return exit_invalid_input
    }
  }
  let exec = @vizprocess.run_process(process)
  let artifact_paths : Map[String, String] = Map::new()
  for a in exec.artifacts {
    let path = out_dir + "/" + a.id + artifact_extension(a.kind)
    match write_file(path, a.content + "\n") {
      Ok(_) => artifact_paths[a.id] = path
      Err(e) => {
        println("error: cannot write artifact '" + a.id + "': " + e)
        return exit_artifact_write_failed
      }
    }
  }
  println(format_status_json(exec, artifact_paths))
  if exec.status == @vizprocess.EsSuccess {
    exit_ok
  } else {
    exit_validation_failed
  }
}

///|
fn read_file(path : String) -> Result[String, String] {
  try @fs.read_file_to_string(path) catch {
    err => Err(err.to_string())
  } noraise {
    s => Ok(s)
  }
}

///|
fn write_file(path : String, content : String) -> Result[Unit, String] {
  try @fs.write_string_to_file(path, content) catch {
    err => Err(err.to_string())
  } noraise {
    _ => Ok(())
  }
}

///|
/// Return the directory portion of `path`, or "" when there is no slash.
fn dirname(path : String) -> String {
  let mut last_slash = -1
  for i in 0..<path.length() {
    if path[i].to_int() == '/'.to_int() {
      last_slash = i
    }
  }
  if last_slash < 0 {
    ""
  } else {
    path[0:last_slash].to_string()
  }
}
