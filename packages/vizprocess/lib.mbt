///|
/// M0 placeholder. Real orchestration arrives in M4.
pub fn version() -> String {
  "0.1.0"
}

///|
pub fn pipe_version() -> String {
  @pipe.version()
}

///|
pub fn viz_version() -> String {
  @viz.version()
}

///|
test "vizprocess wires sub-packages" {
  inspect(pipe_version(), content="0.1.0")
  inspect(viz_version(), content="0.1.0")
}
