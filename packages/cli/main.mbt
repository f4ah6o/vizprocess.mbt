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
  println("  vizprocess process-run <csv-path> <output-dir>")
  println("  vizprocess version")
  println("  vizprocess help")
  println("")
  println(
    "M5a only ships the hardcoded sales-bar process. The full manifest JSON",
  )
  println("loader arrives in M5b.")
}

///|
fn cmd_process_run(args : Array[String]) -> Int {
  if args.length() != 4 {
    println("error: process-run requires <csv-path> <output-dir>")
    return exit_invalid_input
  }
  let csv_path = args[2]
  let out_dir = args[3]
  let read_result : Result[String, String] = try
    @fs.read_file_to_string(csv_path)
  catch {
    err => Err(err.to_string())
  } noraise {
    s => Ok(s)
  }
  let csv_text = match read_result {
    Ok(s) => s
    Err(e) => {
      println("error: cannot read CSV at '" + csv_path + "': " + e)
      return exit_source_read_failed
    }
  }
  let (process, parse_diags) = build_sales_bar_process(csv_text)
  if parse_diags.length() > 0 {
    println(
      "error: CSV parse failed (" +
      parse_diags.length().to_string() +
      " diagnostic(s))",
    )
    return exit_validation_failed
  }
  let exec = @vizprocess.run_process(process)
  let artifact_paths : Map[String, String] = Map::new()
  for a in exec.artifacts {
    let path = out_dir + "/" + a.id + artifact_extension(a.kind)
    let write_result : Result[Unit, String] = try
      @fs.write_string_to_file(path, a.content)
    catch {
      err => Err(err.to_string())
    } noraise {
      _ => Ok(())
    }
    match write_result {
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
