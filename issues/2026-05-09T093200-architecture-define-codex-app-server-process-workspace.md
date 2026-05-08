# Define Codex App Server process workspace contract for vizprocess.mbt

Created: 2026-05-09
Model: GPT-5 Codex

## Background

`vizprocess.mbt` currently exposes a browser demo with:

- manifest JSON editing
- dataset/chart/artifact manipulation
- validate/render Worker routes
- attachment import
- OPFS-backed local workspaces
- browser-side WebMCP tools

That is useful as a local prototype, but it keeps the application model tied to
browser-local persistence and source resolution. The target architecture for
Codex integration should instead be a durable App Server-managed workspace that
clients can reopen, inspect, mutate, and export.

As of 2026-05-09, Codex App Server is the preferred rich-client integration
surface for Codex. It supports resumable sessions, server notifications,
approval requests, apps/connectors, and tool-based mutation. `vizprocess.mbt`
needs an explicit `process workspace` contract for that model.

## Proposal

Redefine the current editor as an App Server-oriented process workspace.

- Move the conceptual source of truth from browser-local OPFS to an App
  Server-managed workspace/session model.
- Treat OPFS as a reference implementation, not as the target architecture.
- Model manifest source, resolved sources, attachments, diagnostics, preview
  outputs, and selection as durable session state.
- Define validate/render/export/import flows as App Server tools rather than as
  browser-only helper actions.
- Target a future VS Code graph/process editor implemented from a shared repo.

The repo-local responsibility is to define the domain workspace contract and its
approval boundaries. The future shared repo will own the reusable client.

## Session Snapshot

The vizprocess session snapshot should include at least:

- workspace id and metadata
- manifest source
- resolved source summary
- dataset nodes
- chart nodes
- artifact nodes
- attachment inventory
- selected node
- diagnostics
- preview outputs, including SVG/HTML/JSON artifact summaries
- last validate/render result metadata

## Read-only Tools

The read-only App Server tools should cover at least:

- read active session snapshot
- inspect manifest source
- inspect resolved sources
- list attachments
- validate current process without mutating source
- render preview outputs
- inspect diagnostics
- inspect artifact summaries

These operations should not require approval.

## Mutating Tools

The mutating App Server tools should cover at least:

- replace manifest source
- upsert dataset node
- upsert chart node
- upsert artifact node
- change selected node
- import attachment
- remove attachment
- export current process bundle
- trigger validate and persist resulting session state
- trigger render and persist resulting session state

These must be expressed as durable workspace mutations rather than browser tab
actions.

## Approval-required Actions

Approval policy should follow the shared cross-repo rule:

- attachment deletion is approval-required
- external connector or file-system writes are approval-required
- export that writes durable artifacts outside the session is approval-required
- pure inspect, validate, render-preview, and read actions are not
  approval-required

If future source resolution touches external systems, those boundaries should
also be approval-gated.

## Import / Export Artifact

The contract should define import/export artifacts for:

- manifest source bundle
- attachment bundle
- rendered artifact bundle
- diagnostic report bundle

It should also define how preview outputs are referenced in session state so the
future shared repo can render them consistently.

## Diagnostic Shape

The App Server contract should expose a structured diagnostic shape with:

- code
- severity
- target
- message
- hint
- context

The shape should cover manifest parse failures, source resolution failures,
validation failures, render failures, and attachment-related failures.

## Selection / Focus State

The contract should expose:

- selected node kind
- selected node id
- active panel or inspector context when needed
- current workspace identity

This allows App Server clients to restore graph/process editing context across
sessions.

## Preview / Navigation State

The contract should expose preview state as session state, not only as browser
DOM.

It should support:

- current preview artifact
- current render mode
- navigation among available artifact outputs
- state needed to reopen the same preview after resume

## Shared Repo Dependency

This issue assumes a new shared repo will be created before implementation
starts.

That shared repo is expected to own:

- the reusable Codex App Server client
- the VS Code extension shell
- shared approval UX
- cross-repo session restoration and notification handling

`vizprocess.mbt` remains responsible for the process-workspace contract,
including source resolution, attachment lifecycle, artifact preview semantics,
and diagnostics.

## Acceptance Criteria

- [ ] The editor surface is specified as an App Server `process workspace`
      contract rather than an OPFS-first browser demo.
- [ ] A session snapshot shape is defined that includes manifest source,
      resolved sources, nodes, attachments, diagnostics, selection, and preview
      outputs.
- [ ] Read-only and mutating tools are listed separately.
- [ ] OPFS is explicitly demoted to a reference implementation.
- [ ] Approval boundaries are defined for destructive and externalized actions.
- [ ] The issue is suitable as specification input for a future shared repo and
      VS Code graph/process editor client.

## Non-goals

- Implementing the shared repo in this issue
- Implementing a VS Code extension in this repo
- Treating the current OPFS demo as the target architecture
- Solving every future storage backend in the first contract draft

## Rationale

`vizprocess.mbt` already has most of the domain ingredients needed by an
agent-friendly application: structured manifest editing, source resolution,
attachment handling, diagnostics, and render artifacts. The missing piece is a
durable workspace contract that a real App Server client can own.

Writing that contract now prevents the future shared repo from inheriting
browser-local assumptions and makes it possible to build a VS Code editor that
can reopen the same process session, inspect nodes, validate, render, and
export without depending on OPFS.
