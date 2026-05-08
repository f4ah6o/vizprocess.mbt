import { listOpfsFiles, readOpfsFile, writeOpfsFile } from "../opfs.mjs";

const WORKSPACE_KEY = "vizprocess.editor.workspace-id";
const WORKSPACE_ROOT = "vizprocess-editor/workspaces";

export function workspaceManifestPath(workspaceId) {
  return `${WORKSPACE_ROOT}/${workspaceId}/manifest.json`;
}

export function workspaceFilesPrefix(workspaceId) {
  return `${WORKSPACE_ROOT}/${workspaceId}/files`;
}

export function loadCurrentWorkspaceId() {
  return localStorage.getItem(WORKSPACE_KEY) ?? "";
}

export function saveCurrentWorkspaceId(workspaceId) {
  localStorage.setItem(WORKSPACE_KEY, workspaceId);
}

export function createWorkspaceId() {
  const stamp = new Date().toISOString().replaceAll(/[:.]/g, "-");
  return `workspace-${stamp}`;
}

export async function loadWorkspaceManifest(workspaceId) {
  try {
    return await readOpfsFile(workspaceManifestPath(workspaceId));
  } catch {
    return "";
  }
}

export async function saveWorkspaceManifest(workspaceId, source) {
  await writeOpfsFile(workspaceManifestPath(workspaceId), source);
}

export async function writeWorkspaceFile(workspaceId, fileName, text) {
  const safeName = sanitizeFileName(fileName);
  const path = `${workspaceFilesPrefix(workspaceId)}/${safeName}`;
  await writeOpfsFile(path, text);
  return path;
}

export async function listWorkspaceFiles(workspaceId) {
  return listOpfsFiles(workspaceFilesPrefix(workspaceId));
}

function sanitizeFileName(input) {
  return input.replaceAll(/[^A-Za-z0-9._-]/g, "-");
}
