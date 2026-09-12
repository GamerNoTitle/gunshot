# Google Photos 7.92.0 の手動・自動バックアップ連携

## 実機診断と変更理由

追加診断では GMUAssetUploadRequest.start → GMUUploadRequest.startFetcher →
GMUUploadMediaRequest.uploadFetcherDidCompleteWithData:error: → native completion
が観測されました。旧フックは PHSBackupActionBehaviorImpl / PHSActionsGridModel
の backupLocalAssets: だけで、別の手動操作と自動バックアップを捕まえていません。

jailed ではアプリ起動時に GMUAssetUploadRequest.start と
GMULivePhotoSingleUploadRequest.start を捕まえます。両者の asset は、7.92.0 の
ivar メタデータで PHAsset と確認済みです。credentials は
GMUUploadRequestCredentials → PHSBaseWithAccountID.accountID を通して、現在の
PHSAccountManagerImpl.viewingAccount.accountID と比較します。

## 処理

1. Google Photos の手動・自動スケジューラーが PHAsset のアップロード要求を作成。
2. 連携が有効なら、送信先と現在のアカウントを照合し、PhotoKit の原本を GoToHP
   の永続キューへ取り込む。元の start はここでは実行しない。
3. Go のジョブが実際に completed となり、mediaKey が存在するまで待機。
4. 元の start を再開し、Google の既存 fingerprint 確認でサーバーの実データを
   照合する。ネイティブの成功結果・PhotosMCMediaItem は捏造しない。
5. native の startFetcher / startCNDEUpload / Scotty の送信へ進んだ場合は失敗として
   止める。GoToHP の失敗を純正アップロードへ自動フォールバックしない。

fingerprintDidComplete:error: の逆アセンブルでは
`enqueueRequestWithCredentials:fingerprint:completion:`、
`uploadRequest:didDiscoverFingerprintExists:mediaKey:`、
`existenceCheckDidFailWithFingerprint:` が確認でき、最後の経路が実データ送信へ
つながります。再照合失敗時には純正側にバックアップエラーが残り得ます。
Go 側の成功と純正側の再照合成功は診断で別々に数えます。既存 fingerprint の成功分岐では success=YES、resultantMediaItem=nil、error=nil が渡されます（framework 内 0x1a218a4 / 0x1a219ac）。mediaKey は別の didDiscoverFingerprintExists callback で通知されるため、nil の media item を再照合失敗とは扱いません。

## 使い方

- GoToHP の「画質」を「オリジナル画質」にする。
- 「手動・自動バックアップを GoToHP へ送る」を有効にする。
- 有効化後の純正バックアップ操作では GoToHP 画面・確認ダイアログを開かず、保存済みの送信先と画質で処理する。
- 自動バックアップには Google Photos 本体のバックアップもオンにする。
- この変更は有効化後に開始した要求が対象。既に送信中の純正要求を取り消す
  ものではないので、切替後にアプリを起動し直して検証する。
- jailed / LiveContainer ではアプリが停止・終了すると独立 daemon としては
  動作しない。Google Photos を前面で開くと永続キューを再開する。
- rootful/rootless は従来の手動 UI 連携を維持。今回の共通要求置換は jailed 対象。

## オリジナル画質

PhotoKit の photo / video / pairedVideo の原本リソースを使用します。
Go commit の field 7=3、初代 Pixel XL profile が original、field 7=1 が saver です。
通常 quota モードも field 7=3、Pixel 8 profile を使用します。
旧 CommitUpload スキーマでは field 7 を Quality と呼んでいますが、7.92.0 の
正式クライアント側の名称は storagePolicy です。field 10 の uploadQuality=1 は
OriginalBytes を意味します。1 を Storage Saver と解釈して変更してはいけません。
テストでは実際にシリアライズした protobuf を HTTP テストサーバーで読み取ります。

original は ForceUpload を指定します。旧経路は同じハッシュが既にサーバーに
あれば画質を確認せず終了していたため、以前の saver の結果を original の
成功として扱うおそれがありました。ローカルキュー内の重複防止は維持します。ただし旧版の original 完了記録は画質未検証のため、新しい original 要求を省略する根拠にはしません。新しい原本送信を実行したジョブには originalPolicy=1 を保存します。
Google 側が既存メディアの画質を更新するか、quota をどう計上するかは別の
実機検証事項です。圧縮済みファイルから失われた品質を復元する機能ではありません。

## 診断・検証

`backupRouting` に intercepted / queued / reconciling / nativeReconciled /
reconcileFailed / nativePayloadBlocked / accountMismatch / failed / unsupported
の件数を記録します。トークン・メール・asset ID・mediaKey は出力しません。

## 追加診断 4 と表示・同期の修正

利用者が Web の同一写真を確認し、オリジナル画質と報告しました。今回の症状は
送信 profile の違いではありません。[表示と同期の解析](original-quality-display.md)
に upstream 2 実装・enum・iOS の表示判定を記録しています。

旧 backupLocalAssets: フックは GoToHP 画面へ直接移譲して共通要求を迂回し、
診断 4 の events / backupRouting 件数が空になっていました。jailed で共通要求
フックが利用できる場合は純正 UI の要求作成を通し、その要求で GoToHP へ移譲します。
これにより純正の delegate と完了時の fingerprint 再照合が維持されます。

GoToHP 単独のアップロードを含め、永続化された完了 revision を前景で監視し、
現在のアカウントの既存 PHSUserItemsSynchronizer.fetchData に差分同期を要求します。
設定画面を閉じても動作します。アプリがまだ同期オブジェクトを公開していない場合は
次の純正 fetchData / fetchDataSoft まで保留します。要求の成功とサーバーからの反映は
同義ではなく、通信と Google の反映待ちは発生します。

## 画面なしの手動操作

旧互換経路（共通要求フックが使えない jailed と rootful/rootless の手動 UI）も、
GoToHP 画面を生成する処理を廃止しました。PhotoKit の原本を書き出し、保存済みの
アカウント・画質で永続キューへ直接追加します。ファイル処理は専用の直列キューで
行い、画面を塞ぎません。通常の jailed 共通要求では純正の進捗・完了経路を維持します。

アカウント不一致、未対応/ロック済み写真、書出し失敗は純正送信に切り替えません。
取込前の失敗は GoToHP 設定画面の状態と診断 manualRouting.lastError に表示し、
取込後のアップロード結果は永続キューの履歴で確認します。診断の actions / queued /
failed は互換経路の累計で、個人情報や原本の内容を含みません。

連携を有効にする時の送信先確認と、ユーザーが自分で開く GoToHP 設定・アップロード
画面は維持します。毎回の純正バックアップ操作から画面を開く処理はありません。

ネイティブ fixture は UI を経由しない自動要求も同じ start で検証し、
アカウント不一致・二重 start・キャンセル・原本の画質指定・Go 完了後の再照合・
再照合時の native payload ブロックを確認します。実 Google サーバーでの完了、
HEIC / MOV / Live Photo のサーバー再照合と画質表示は端末での確認が必要です。
