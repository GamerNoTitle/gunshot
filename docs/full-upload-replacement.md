# 全アップロード置換の実装状況と次の実機確認

**全置換は未完成です。この変更は対応可否を確認する診断機能で、標準アップロードを GoToHP に切り替えません。** 手動 action の転送は従来どおり別設定です。

## 静的に確認できた境界

提供された Google Photos 7.92.0 IPA の Objective-C metadata に、次の経路がありました。

| 層 | entry / completion | 全置換で必要なこと |
| --- | --- | --- |
| Asset request | GMUAssetUploadRequest.start | PHAsset と native request の関連付け、キャンセルと retry の同期 |
| Live Photo | GMULivePhotoSingleUploadRequest.start | ペア単位の完了と内部モデルの受け渡し |
| Swift Scotty | ScottyUploadServiceImpl.uploadWithAsset:… | foreground/background 経路、NSData/NSError completion の互換性 |
| Stateless Scotty | statelessUploadWithAsset:… | 通常 request と異なる経路の網羅 |
| Legacy fetcher | GMUUploadRequest.startFetcher | 新経路以外から native 送信が漏れないこと |
| Native commit | didCompleteWithSuccess:resultantMediaItem:error: | 成功状態と実際の resultantMediaItem の整合 |
| Locked folder | PHSLockedPhotoMediaUploadRequest / PHSLockedPhotoLivePhotoSingleUploadRequest | 保存先・暗号化・公開範囲を変えないこと |

gotohp の `parseCreateMediaItemsResponse` は、確認済みの mediaKey だけを Go 側へ返します。native `resultantMediaItem` の完全な互換オブジェクトは返しません。native 成功 callback に単に mediaKey や空オブジェクトを渡して成功を宣言する実装はありません。

Scotty のみに hook しても legacy/background reconnect を網羅した証明にはなりません。逆に native 送信を一括拒否すると、未対応経路の写真がアップロードされなくなります。この診断版ではいずれの変更もしていません。

## 診断ビルドの使い方

rootless / rootful / jailed の同じビルドから使用できます。Google Photos **7.92.0** が対象です。

1. **GoToHP → Settings** で **Route Google Photos backup action** を OFF にします。GoToHP 手動転送を有効にしたままでは標準経路を観測できません。
2. **Upload compatibility diagnostics** を ON にします。ON にするごとにメモリ内の履歴をクリアします。プロセス再起動時は OFF です。
3. 標準の手動バックアップと自動バックアップを、それぞれ小さいテスト画像で実行します。これは Google Photos 本来の送信であり、GoToHP の容量 policy は適用されません。写真・動画・Live Photo は別々に調べます。
4. アプリを強制終了せず、**Export upload diagnostics** で JSON を Files に保存します。診断を OFF にしても取得済み履歴は export できます。
5. JSON と、どの操作を試したか・成功/失敗・iOS/LiveContainer のバージョンを提供してください。token や credential の添付は不要です。

記録はメモリ内の直近 256 件と累計イベント数です。binding 名、適合した ABI、result の Objective-C クラス名、failure の有無だけを含みます。写真、ファイル名、URL、HTTP header/body、account、token、mediaKey、NSError 本文は読み取りません。`description` も呼びません。export した JSON 以外の永続ログを作らず、外部送信もしません。

診断は loader が GoToHP ボタンを設置した後の既知 entry を観測するもので、起動直後や任意の別経路を全て捕捉できる保証はありません。`bindings[].matched=false` は当該 method の ABI 不一致/未ロードを示します。成功イベントがゼロなら互換性が確認できたとは扱いません。

## 残る実装と gate

- native completion model の型・schema・サーバー結果への対応を確定する。
- native Google account と GoToHP destination の一致を確認する。
- upload request と GoToHP durable job の ID を関連付け、native cancel/retry/progress を同期する。
- 既存 background URLSession、Scotty stateless、legacy、Live Photo、編集済みコンテンツ、共有、locked folder の各経路を対応または明示的に扱う。
- native 送信が並走しないこと、成功していない asset を backed up と表示しないことを実機で検証する。

現時点で iPhone / LiveContainer の実行環境は接続されていません。CI の mock tests とビルド成功だけでは、これらの gate を通過したとは判断できません。
