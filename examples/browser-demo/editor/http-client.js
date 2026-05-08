export async function postEditorJson(path, body) {
  const response = await fetch(`/api/editor/${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${path} failed: ${response.status} ${response.statusText}\n${text}`);
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Invalid JSON from /api/editor/${path}: ${text}`);
  }
}
