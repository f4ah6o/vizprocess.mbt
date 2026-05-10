# approval と preview artifact bundles を追加する

Created: 2026-05-10
Model: GPT-5 Codex
Category: integration
Status: closed

## Summary

attachment delete、external export approval、preview/artifact bundle、diagnostic report envelope を実装する。

## Why

vizprocess は data source と artifact を扱うため、削除や外部書き出しは App Server client で承認可能にする必要がある。また、rendered artifacts や diagnostics を stable bundle として取り出せると、レビュー、回帰テスト、他 client への handoff がしやすくなる。

後方互換性は不要なので、既存 demo の OPFS export 形状より App Server artifact envelope を優先する。

## Scope

- `remove_attachment` approval proposal の shape を定義する。
- `export_process_bundle` approval proposal の shape を定義する。
- Export formats: `manifest-source`、`attachments`、`rendered-artifacts`、`diagnostic-report`。
- Preview output は artifact id、kind、previewRef、content metadata を持つ。
- External destination への書き出しは approval-required とする。

## Acceptance Criteria

- [x] attachment delete proposal に workspace id、path、size、effects が含まれる。
- [x] external export proposal に format、destination、estimated effects が含まれる。
- [x] manifest source bundle が stable envelope を持つ。
- [x] attachment bundle が stable envelope と payload references を持つ。
- [x] rendered artifact bundle が stable envelope を持つ。
- [x] diagnostic report bundle が stable envelope を持つ。
- [x] Tests or fixtures cover approval proposal and all export bundle formats.

## Non-goals

- UI confirmation dialog 実装
- すべての external destination 実装
- binary archive format の固定
- 既存 OPFS export 互換

## Rationale

App Server integration では、artifact を安全に外へ出す境界が重要になる。approval と bundle envelope を定義すると、vizprocess の出力を自動化しながら、ユーザーが破壊的操作と外部書き出しを確認できる。

## Resolution

`packages/vizprocess/app_server_tools.mbt` に export bundle format、approval proposal 詳細、preview content metadata、`ExportBundleEnvelope` を追加した。attachment delete は workspace id / path / size / effects を持つ proposal を返し、external export は format / destination / estimated effects を持つ approval-required proposal を返す。`export_process_bundle` は manifest source、attachments、rendered artifacts、diagnostic report の stable envelope を生成する。HTTP/UI/external storage connector は non-goal のまま実装していない。
