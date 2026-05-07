// Thin helpers around the Origin Private File System so the demo can
// persist CSVs across reloads (and use them as a `csvReader` in the
// shared prefetch path). Browser-only — Node has no `navigator.storage`.
//
// Paths use POSIX-style forward slashes; intermediate directories are
// created lazily on write.

async function opfsRoot() {
  if (
    typeof navigator === "undefined" ||
    !navigator.storage ||
    !navigator.storage.getDirectory
  ) {
    throw new Error("OPFS is not available in this environment");
  }
  return await navigator.storage.getDirectory();
}

async function resolveDir(root, segments, { create }) {
  let dir = root;
  for (const seg of segments) {
    if (!seg) continue;
    dir = await dir.getDirectoryHandle(seg, { create });
  }
  return dir;
}

function splitPath(path) {
  const parts = path.split("/").filter((p) => p.length > 0);
  if (parts.length === 0) {
    throw new Error("OPFS path is empty");
  }
  const file = parts.pop();
  return { dirs: parts, file };
}

export async function writeOpfsFile(path, text) {
  const root = await opfsRoot();
  const { dirs, file } = splitPath(path);
  const dir = await resolveDir(root, dirs, { create: true });
  const handle = await dir.getFileHandle(file, { create: true });
  const writable = await handle.createWritable();
  await writable.write(text);
  await writable.close();
}

export async function readOpfsFile(path) {
  const root = await opfsRoot();
  const { dirs, file } = splitPath(path);
  const dir = await resolveDir(root, dirs, { create: false });
  const handle = await dir.getFileHandle(file, { create: false });
  const f = await handle.getFile();
  return await f.text();
}

export async function deleteOpfsFile(path) {
  const root = await opfsRoot();
  const { dirs, file } = splitPath(path);
  const dir = await resolveDir(root, dirs, { create: false });
  await dir.removeEntry(file);
}

export async function listOpfsFiles(prefix = "") {
  const root = await opfsRoot();
  const segments = prefix.split("/").filter((p) => p.length > 0);
  let dir;
  try {
    dir = await resolveDir(root, segments, { create: false });
  } catch {
    return [];
  }
  const out = [];
  for await (const [name, handle] of dir.entries()) {
    if (handle.kind === "file") {
      out.push(prefix ? `${prefix}/${name}` : name);
    }
  }
  out.sort();
  return out;
}

export async function clearOpfs() {
  const root = await opfsRoot();
  for await (const [name] of root.entries()) {
    await root.removeEntry(name, { recursive: true });
  }
}

// `csvReader`-compatible function backed by OPFS. Pass it directly to
// `prefetchManifestSources` to make `csv-file` sources read from the
// origin-private filesystem instead of the network.
export function opfsReader() {
  return async (path) => readOpfsFile(path);
}
