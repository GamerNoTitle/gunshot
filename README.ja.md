# GoToHP for iOS — Gunshot

[English](README.md) · [日本語](README.ja.md)

Jailbreak・サイドロード・LiveContainer 向けの Google Photos アップローダー。[xob0t/gotohp](https://github.com/xob0t/gotohp) の Go コアを使い、jailbreak 版は独立した daemon、jailed 版は Google Photos 内でアップロードします。

**開発版です。** 解析済みの対応プロファイルは Google Photos **7.20.2（iOS 16.1以降）** と **7.92.0（iOS 18.0以降）** です。[バージョン互換性の解析](docs/analysis/google-photos-7.20.2.md)を参照してください。互換性は実機での確認が必要で、未対応バージョンではバージョン固有の連携が無効になります。

## スクリーンショット

<p>
  <img src="docs/images/unlimited-storage.png" width="240" alt="Google Photos 純正の無制限ストレージ表示">
  <img src="docs/images/profile-menu.png" width="240" alt="プロフィールメニュー内の GoToHP の設定">
</p>
<p>
  <img src="docs/images/upload-settings.png" width="240" alt="ログイン中アカウントと Pixel 1 のオリジナル画質設定">
  <img src="docs/images/backup-routing.png" width="240" alt="手動・自動バックアップの転送とキュー管理の設定">
  <img src="docs/images/appearance-settings.png" width="240" alt="表示言語と無制限ストレージ表示の切り替え">
</p>

## 免責事項 / Disclaimer

Google・Apple とは無関係の非公式プロジェクトです。**現状のまま、無保証で提供**します。非公式 API やアプリ更新により動作しなくなるほか、アカウント制限・データ損失・容量料金が発生する可能性があります。元の写真・動画は別途バックアップしてください。Google Photos のバイナリ・署名証明書・認証情報は配布しません。

## インストールと使い方

> [!IMPORTANT]
> **tweak の導入・有効化より先に Google Photos 本体へログインしてください。** Sideloadly で注入を有効にすると、Google にログインを拒否された報告があります。
>
> 1. 注入なしの Google Photos をインストールし、Google アカウントへログインします。
> 2. アプリを終了し、jailbreak では tweak を導入・有効化、サイドロードでは注入済み IPA を上書きします。**同じ署名アカウント・Bundle ID・アプリデータ**を維持してください。LiveContainer では**同じ guest／データコンテナ**で tweak を有効化するか IPA を更新します。
> 3. **Google Photos のプロフィールメニュー → GoToHP の設定**を開きます。
>
> ログイン済みアプリ・guest の削除や、新しいデータコンテナの作成は避けてください。App Store 版から別署名のアプリへ移す場合など、ログイン状態の維持は保証されません。[詳しい導入手順](docs/jailed.md)。

### サイドロード / LiveContainer

[GitHub Actions](https://github.com/tqmane/gunshot/actions) の `gotohp-tweak-jailed` に `.deb`、`GunshotJailed.dylib`、notices を同梱しています。[導入ガイド](docs/jailed.md)に従い、パッケージを注入するか LiveContainer に dylib を取り込みます。

Google Photos のログイン中アカウントへ接続します。**アップロード → 写真・動画を選択**からアップロードできます。**Google Photos は前面で開いたままにしてください。** jailed 版はアプリを閉じると送信を継続できません。

jailed / Google Photos 7.20.2・7.92.0 の**手動・自動バックアップを GoToHP へ送る**は既定 OFF です。有効にして送信先を確認すると、GoToHP を開かずに対応するバックアップ操作を転送します。自動バックアップには Google Photos 側のバックアップも ON にしてください。[対応経路](docs/analysis/backup-routing.md)と[未対応の範囲](docs/full-upload-replacement.md)。

### Jailbreak

GitHub Actions の `gotohp-tweak-rootless` または `gotohp-tweak-rootful` の `.deb` をパッケージマネージャーで導入します。RocketBootstrap、PreferenceLoader、substrate 互換の注入環境が必要です。

**設定 → GoToHP → Open GoToHP settings** で、[upstream のサインイン手順](https://github.com/xob0t/gotohp#sign-in)に従いアカウントを取り込みます。Google Photos の GoToHP 設定、Apple Photos の GoToHP ボタン、対応する共有シートの **Upload with GoToHP** からアップロードできます。キューへの受け渡し完了まではアプリを開いておき、その後は daemon が送信を続けます。

## 画質とキュー

| 設定 | デバイスプロファイル / リクエストする動作 |
| --- | --- |
| オリジナル | Pixel XL（Pixel 1）、オリジナル画質・容量不使用 |
| 容量節約 | Pixel 2、容量節約画質 |
| アカウントの保存容量を使用 | Pixel 8、オリジナル画質・通常の容量を使用 |

リクエストする動作であり、結果の保証ではありません。元データの取得可否と Google 側の容量使用量は別途確認してください。アップロード成功だけでは容量の扱いは判断できません。アカウント・画質はキュー追加時に固定され、設定変更は既存の項目に影響しません。

PhotoKit の元データを再エンコードせず使い、Live Photo は写真と動画のペアを送信します。キューは進捗表示・再試行・キャンセル・再起動後の復旧に対応。再試行はファイルの先頭からです。確定処理の中断で結果が不明な場合は手動確認・再試行が必要で、重複する可能性があります。キャンセルしても Google Photos に保存済みの写真・動画は削除しません。

## 表示言語

日本語・英語に対応。**GoToHP の設定 → 表示 → 表示言語**で選べます。未対応の端末言語では英語を使い、翻訳ファイルの追加注入は不要です。[翻訳の追加方法](docs/localization.md)。

## ビルド

macOS、Xcode command line tools、Go 1.26.0、Theos、`ldid`、`dpkg` が必要です。

```sh
git clone --recurse-submodules https://github.com/tqmane/gunshot.git
cd gunshot
export THEOS="$HOME/theos"
bash scripts/package.sh jailed  # または rootless / rootful
```

ローカルでの確認:

```sh
python3 scripts/localization.py --check
python3 scripts/prepare-core.py
go test -race -tags cli ./...
go test -tags cli app/backend
go vet -tags cli ./...
```

CI でテストと 3 方式のビルドを行い、`v*` タグの成功時に Release へ配布物を添付します。upstream の更新は `bash scripts/sync-upstream.sh [commit]`。配布時は upstream のライセンスと生成された notices を同梱してください。

## 開発資料

- [構成・認証情報・upstream 連携](docs/architecture.md)
- [Google Photos 解析](docs/analysis/index.md)（日本語）
- [実機チェック](docs/device-validation.md)
