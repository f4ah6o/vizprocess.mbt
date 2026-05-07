///|
/// M0 placeholder. Real types arrive in M1.
pub fn version() -> String {
  "0.1.0"
}

///|
test "pipe version" {
  inspect(version(), content="0.1.0")
}
