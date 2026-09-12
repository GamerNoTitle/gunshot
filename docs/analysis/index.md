# Google Photos 7.92.0 アプリ解析結果・総合索引

提供 IPA に対してこれまで行った解析結果の入口です。**アプリ全機能の意味・動作を解析し終えたという意味ではありません。** 全件抽出した metadata と、処理まで追った箇所、未確認の箇所を以下に整理しています。

## 読みたい情報から探す

| 対象 | 参照先 | 確認水準 |
| --- | --- | --- |
| 全クラス名・instance selector・encoding・static IMP | [機械可読全件索引](objc/README.md) | metadata 抽出済み |
| 入力同定・件数・SHA-256 | [manifest](objc/manifest.json) | 対象 2 image の照合情報 |
| upload / backup / Live Photo / account 周辺のクラス | [アップロード関連クラス索引](upload-symbols.md) | 今回参照したクラスの全 instance method |
| 手動バックアップ action | [native-routing.md](../native-routing.md) | version / ABI 確認、hook 実装、mock test |
| 自動バックアップ・Scotty・legacy の境界 | [full-upload-replacement.md](../full-upload-replacement.md) | metadata・一部 call path 確認、実機は未確認 |
| native completion の内部依存 | [completion-analysis.md](completion-analysis.md) | 限定した関数の逆アセンブル追跡 |
| Go uploader / 認証 / commit / Live Photo | [architecture.md](../architecture.md) | upstream source と iOS bridge の解析 |
| iOS 側の構成・画質・queue | [README](../../README.md) | 実装と CI。実機 upload は未確認 |
| `.deb` 注入・jailed・LiveContainer | [jailed.md](../jailed.md) | ビルド / 配布手順 |
| 実機で確認すべき項目 | [device-validation.md](../device-validation.md) | 実行待ちの検証項目 |
| 未解析領域と限界 | [coverage.md](coverage.md) | 網羅性の境界 |

## 対象アプリ

- 提供ファイル: `com.google.photos-7.92.0-eeveedecrypter.ipa`
- Bundle ID: `com.google.photos`
- Executable: `GooglePhotos`
- Version: `7.92.0` / MinimumOSVersion: `18.0`
- `NSPhotoLibraryUsageDescription`: 存在を確認
- metadata 抽出先: メイン executable と `GooglePhotos_GeneratedFramework.framework`
- 総数: **26,183 class entries / 165,016 instance-method entries**（image 別件数の和）

クラス名や selector はコード検索用の識別子です。索引の名前から機能の実装や API 対応を推定して「確認済み」にしないでください。例えば account 関連 selector の存在確認と、実際の account/token format の確認は別です。

## GoToHP から参照する native 境界

| 境界 | 主なクラス・selector | 実装での扱い |
| --- | --- | --- |
| 手動 backup | PHSBackupActionBehaviorImpl / PHSActionsGridModel → backupLocalAssets: | 7.92.0 / encoding 一致時のみ opt-in 転送 |
| 選択 asset | PHSLocalAsset → phAsset / isLocked | PhotoKit asset を解決、locked を転送対象にしない |
| native asset request | GMUAssetUploadRequest → start / completion | 診断のみ。全置換は未実装 |
| native Live Photo | GMULivePhotoSingleUploadRequest | 診断のみ。native 完了モデルの互換性未確定 |
| Swift transport | ScottyUploadServiceImpl → uploadWithAsset:… / statelessUploadWithAsset:… | 前景 / 背景 / stateless の受動診断 |
| legacy transport | GMUUploadRequest → startFetcher | 受動診断 |
| native result | resultantMediaItem / metadata / dedupInfo | 空 object や mediaKey string で成功を偽装しない |
| UIKit 入口 | UIWindow / UIActivityViewController | 常設ボタン・共有 action。実機 UI 検証待ち |

## 検証履歴

- [PR #1](https://github.com/tqmane/gunshot/pull/1): daemon / bridge / queue / UI の初期実装。
- [PR #2](https://github.com/tqmane/gunshot/pull/2): jailed / LiveContainer 用成果物、アプリ内設定、手動 action 転送。
- [PR #3](https://github.com/tqmane/gunshot/pull/3): 全置換に必要な native uploader の受動診断。
- [診断版 CI](https://github.com/tqmane/gunshot/actions/runs/34673212132): Go / C ABI / native mock tests / 3方式の iOS build・package check 成功。実機互換性の証明ではありません。

- [ログイン中アカウントの認証とアカウントメニュー](native-account.md) — jailed の SSO bridge、ログイン拒否の再現条件、メニュー移動。
- [設定メニューのタップ処理と UI 修正](account-menu-tap.md) — dismiss 前のイベント取得、表示先の解決、設定画面の再構成。
