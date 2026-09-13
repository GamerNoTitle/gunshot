# バックアップ転送の対応範囲と実機確認

**通常の手動・自動バックアップの共通要求は jailed / rootless / rootful とも
GoToHP へ転送します。任意の全アップロード経路を網羅した保証はありません。**
API の解析基準は 7.20.2 と 7.92.0。版番号ではなく機能ごとの ABI で判定します。
[使い方](native-routing.md) / [解析と診断](analysis/backup-routing.md)。

| 経路 | 現在の扱い |
| --- | --- |
| GMUAssetUploadRequest.start | 手動・自動の PHAsset 原本を GoToHP の永続キューへ転送 |
| GMULivePhotoSingleUploadRequest.start | 写真・pairedVideo を一組で転送し、純正のサーバー再照合で完了判定 |
| 純正の完了 callback | 旧版の数値 errorCode / 新版の NSError を自動選択。成功結果を捏造しない |
| GMUUploadRequest.startFetcher / startCNDEUpload | 転送有効時・再照合中の native payload fallback を停止 |
| Swift Scotty / statelessUpload | 対応 ABI が存在する場合に payload fallback を停止。7.20.2 では該当 Swift class は未検出 |
| GoToHP の設定から直接送信 | 共通の完了監視が純正 fetchData に表示更新を要求 |
| locked folder / 編集専用 / 共有専用 / 既存 background URLSession | 全経路の移譲を検証できていない。通常の PHAsset バックアップと同等とは扱わない |

Go の completed / mediaKey は、純正のバックアップ成功そのものではありません。
対応する要求では Go の完了後に元の fingerprint 照合を再開し、純正の delegate が
サーバー結果を処理します。別途、前景の完了監視が現在のアカウントの差分同期を
要求します。ネイティブ DB や成功フラグは書き換えません。

## 実機での確認

- 切替 OFF で標準の手動／自動バックアップが元の動作をする。
- ON で単一・複数選択・自動バックアップが一度だけ GoToHP へ渡り、画面を開かない。
- JPEG / HEIC / 動画 / Live Photo の実データ・画質・quota を別々に確認する。
- GoToHP 直接送信と純正からの送信の両方で、設定を閉じたまま完了後に表示が更新される。
- ネットワーク切断、一時停止、Wi-Fi 限定、充電限定で待機し、条件回復後に再開する。
- account 切替、認証失効、PhotoKit 拒否、disk full、再照合失敗時に純正へ再送しない。
- jailbreak では原本取込後のホスト終了でキューを保持し、再度開くと表示が同期される。
  jailed は前景実行が必要で、閉じている間の継続は提供しない。

## 診断

GoToHP 設定の **Upload diagnostics** を有効にし、標準操作を試して
**Export diagnostics** を使います。`backupRouting` の intercepted / queued /
nativeReconciled、`photosIntegration` の syncRequested、`completionMonitor` の
syncSignals / uploadSummary を確認できます。

標準経路そのものを調べるときだけ転送を OFF にします。その場合は純正送信となり、
GoToHP の画質 policy は適用されません。診断はトークン・写真・account ID・mediaKey・
HTTP 本文を記録しません。CI は API fixture、Go queue、パッケージ構成を検証しますが、
Google サーバーの再照合や端末での表示時間を証明するものではありません。
