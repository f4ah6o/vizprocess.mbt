///|
/// M0 placeholder. Real types arrive in M2.
pub fn version() -> String {
  "0.1.0"
}

///|
test "viz version" {
  inspect(version(), content="0.1.0")
}
