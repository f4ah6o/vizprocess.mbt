# process workspace session store を実装する

Created: 2026-05-10
Model: GPT-5 Codex
Category: architecture
Status: closed

## Summary

manifest、resolved sources、nodes、attachments、selection、preview、diagnostics を
durable process workspace として実装する。

## Why

現在の browser demo は OPFS-backed local workspace を持つが、App Server client が再開
できる durable workspace contract にはまだなっていない。manifest source、resolved
sources、attachments、render preview、diagnostics が browser tab の状態に閉じていると、
VS Code client や shared client が同じ process を安全に扱えない。

後方互換性は不要なので、OPFS は reference implementation とし、App Server workspace
session を source of truth とする。

## Scope

- Session store の top-level section を定義する。
- `workspace`、`manifest`、`resolvedSources`、`nodes`、`attachments`、
  `selection`、`preview`、`diagnostics`、`lastAction` を保持する。
- dataset/chart/artifact node の summary projection を定義する。
- manifest parse と validation 後の snapshot 更新規則を定義する。
- preview output reference を session state として保持する。

## Acceptance Criteria

- [x] process workspace snapshot shape が定義されている。
- [x] required top-level section が plan どおり含まれている。
- [x] dataset/chart/artifact nodes が flat summary として取り出せる。
- [x] attachments は stable path、size、mediaType を持つ。
- [x] preview output は resume 可能な reference として保存される。
- [x] OPFS は target architecture ではなく reference implementation として明記されている。

## Non-goals

- Shared App Server repo 実装
- VS Code extension 実装
- すべての storage backend 実装
- 既存 OPFS state key の互換維持

## Rationale

vizprocess の価値は、data source から artifact までを再現可能な process として持てる点に
ある。durable workspace session store によって、その process を browser 外の client からも
再開・検査・変更できる。

## Resolution

`packages/vizprocess/session_store.mbt` に durable process workspace snapshot と
manifest refresh / preview reference 更新 API を追加した。`docs/architecture.md` には
App Server workspace session を source of truth とし、OPFS は reference implementation
であることを明記した。
