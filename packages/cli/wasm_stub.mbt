///|
/// Empty `main` for non-native targets so the package still satisfies
/// `is-main: true` when `main.mbt` is gated out. The CLI itself only
/// works under `native`; the browser entry point lives in
/// `packages/wasm`.
fn main {

}
