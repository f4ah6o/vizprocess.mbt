# App Server process tools を追加する

Created: 2026-05-10
Model: GPT-5 Codex
Category: runtime
Status: closed

## Summary

validate、render、import/export、node edit を App Server tool 境界へ分割する。

## Why

browser demo の validate/render route は便利だが、App Server client には durable
workspace を読む tool、変更する tool、approval が必要な tool の区別が必要である。
process graph editor を実装するには、manifest text だけでなく node summary、attachment、
preview output、diagnostics を tool で扱える必要がある。

後方互換性は不要なので、現行 browser route 名より process workspace tool contract を
優先する。

## Scope

- Read-only tools: snapshot、manifest source、resolved sources、attachments、
  datasets、charts、artifacts、validate current process、render preview、
  diagnostics。
- Mutating tools: replace manifest source、upsert dataset/chart/artifact node、
  select node、import attachment、validate and persist、render and persist。
- Approval-required tools: remove attachment、external destination 付き export。
- 各 tool は diagnostics と updated snapshot を stable JSON envelope で返す。

## Acceptance Criteria

- [x] read-only tools の input / output shape が定義されている。
- [x] mutating tools の input / output shape が定義されている。
- [x] destructive attachment removal が approval-required として定義されている。
- [x] external export が approval-required として定義されている。
- [x] validate/render は preview output と diagnostics を返す。
- [x] Tests cover manifest replace, validate, render, node upsert, attachment
      import, and approval proposal generation.

## Non-goals

- Browser editor UI の全面刷新
- Shared App Server client 実装
- すべての external source resolver 実装
- 既存 Worker route 互換

## Rationale

process tools は App Server client が vizprocess を操作するための主 API になる。tool
境界を定義すれば、browser demo、VS Code editor、future shared client が同じ workspace
semantics を使える。

## Resolution

`packages/vizprocess/app_server_tools.mbt` に App Server process tool の typed boundary
と stable JSON envelope を追加した。remove attachment と external export は直接実行せず
approval proposal を返すようにし、validate / render / manifest replace / node upsert /
attachment import / approval proposal の whitebox tests を追加した。
