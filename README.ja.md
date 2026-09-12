# GoToHP for iOS — Gunshot

[English](README.md) · [日本語](README.ja.md)

Jailbreak / サイドロード / LiveContainer 向け Google Photos uploader。`xob0t/gotohp` の Go upload core を再利用し、jailbreak 版は Google Photos / Apple Photos の入口と常駐 daemon を分離し、jailed 版はアプリ内で実行します。

**開発版です。iPhone での起動・Google 認証・実アップロード・quota 判定は未検証です。** ビルド成功と実機動作は別です。添付された Google Photos 7.92.0 の Info.plist は minimum iOS **18.0** でした。iOS 15/16 の端末では対応する旧版 Google Photos が必要です。

**追加モード:** [サイドロード / LiveContainer の導入と jailed ビルド](docs/jailed.md)。Google Photos 内の **GoToHP → Settings** から設定できます。[手動・自動バックアップを GoToHP へ転送](docs/analysis/backup-routing.md)する設定は jailed / 7.92.0 限定・既定 OFF です。有効化後は純正の手動バックアップを押すだけで、GoToHP 画面を開かずに保存済みの画質・送信先で処理します。Google Photos の自動バックアップをオンにし、アプリを前面で開いて使用します。実機での再照合は検証中です。

[全アップロード置換の状況と診断手順](docs/full-upload-replacement.md)：全置換はまだ未完成です。7.92.0 の native uploader を観測する opt-in 診断・JSON export を追加しています。

[Google Photos 7.92.0 アプリ解析結果・総合索引](docs/analysis/index.md)：全件 metadata 検索、解析済み upload 経路、根拠、未解析領域の入口です。

## 構成（jailbreak 版）

- Theos / Logos tweak: Google Photos のアカウントメニューに GoToHP 設定、Apple Photos に GoToHP ボタン、対応する共有シートに `Upload with GoToHP`。
- PhotoKit: 元の写真/動画を再エンコードせず export。Live Photo は still + pairedVideo の original resources。
- RocketBootstrap + Mach IPC: sandbox から daemon へ bounded chunk transfer。kernel audit token と署名 identifier / executable path で送信元を検証。
- `gotohpd`: mobile ユーザーの launchd daemon。Go `c-archive` をリンク。UI プロセスには Go runtime を載せません。
- Preferences: account の追加・選択・削除、画質、同時数 1–4、再試行回数、Wi-Fi/充電制限、pause、queue/retry/cancel。
- JSON queue: atomic rename + fsync。再起動時の復旧、履歴、account/quality ごとの content fingerprint と remote hash check。

## インストールと使い方

1. GitHub Actions の `gotohp-tweak-rootless` / `gotohp-tweak-rootful` から対応 `.deb` を取得。
2. RocketBootstrap、PreferenceLoader、使用中の jailbreak の substrate-compatible tweak injection が必要です。rootless を優先、rootful は同じソースからビルドします。
3. パッケージマネージャーでインストールし、Photos / Google Photos / Settings を再起動。
4. **jailed:** Google Photos のプロフィール画像 → **GoToHP の設定** でログイン中アカウントを自動接続します。**独立 daemon:** アカウントメニューの GoToHP 設定 → Account、または **設定 → GoToHP → Open GoToHP settings → Account** で `oauth_token` または完全な gotohp credential を入力。
   - 認証入力は upstream と同じ方式です。[upstream のサインイン手順](https://github.com/xob0t/gotohp#sign-in) を参照。
   - jailed の Google Photos 連携ではログイン中アカウントの SSO authorizer に認証を依頼します。独立 daemon では upstream の credential import が必要です。
   - token binding 必須 credential は binding 情報も含めて import してください。iPhone 上の ADB 抽出はありません。
5. Photos / Google Photos の **GoToHP → Upload** で写真ライブラリへのアクセスを許可し、写真/動画を選択。
6. 準備が終わってキューに入るまでアプリを開いておいてください。**Queued 後**はアプリを終了しても daemon が処理します。準備中の強制終了では、その時点までに daemon に受け渡せた項目だけ継続します。
7. 同じ画面で progress / completed / failed を確認。失敗行から Retry / Cancel。複数選択は項目単位でキューに追加します。

共有シートでは `PHAsset` またはローカル file URL が得られる場合に action を表示します。共有データが image object / provider のみの場合や Google Photos 独自共有 UI では、Google Photos のアカウントメニュー → GoToHP の設定 → Upload（Apple Photos では GoToHP ボタン）から写真を選びます。URL 共有は共有元が渡したファイルそのものを使い、Google Photos 内の選択を推測しません。

画質は Preferences の Quality 行をタップして切替:

| 設定 | upstream API policy |
| --- | --- |
| original | Original quality / Pixel XL profile |
| saver | Storage Saver / Pixel 2 profile |
| quota | Original quality / 通常 quota / Pixel 8 profile |

設定は新規 job に固定されます。既存 job の account / quality は変更されません。Google 側に同じ内容が既に存在する場合は再送を省略し、既存 asset の画質を変更しません。API 成功だけで無料・無制限とは判定しません。

## ビルド

macOS + Xcode command line tools + Go 1.26.0 + Theos + `ldid` + `dpkg`:

```sh
git clone --recurse-submodules https://github.com/tqmane/gunshot.git
cd gunshot
export THEOS="$HOME/theos"
bash scripts/package.sh rootless
# または
bash scripts/package.sh rootful
# サイドロード / LiveContainer
bash scripts/package.sh jailed
```

Go archive / daemon は arm64。tweak / Preferences は arm64 + arm64e です。arm64e プロセスへ arm64 Go archive を無理にリンクしません。端末 daemon は独立した arm64 executable で動かします。

CI は Linux の Go race tests / upstream regression tests / C ABI smoke と、macOS の iOS c-archive / Theos / 3 方式の package を検証します。`v*` tag の成功時には `gotohp-tweak-rootless.deb` / `gotohp-tweak-rootful.deb` / `gotohp-tweak-jailed.deb` / `GunshotJailed.dylib` / notices を Release に添付します。

```sh
python3 scripts/prepare-core.py
go test -race -tags cli ./...
go test -tags cli app/backend
go vet -tags cli ./...
```

## 運用上の意味

- `pending → preparing → uploading → committing → completed`。`importing` はまだ端末から受け渡し中。
- 通信失敗は指数 backoff。upstream 内部にも request retry があり、Preferences の回数は **job 単位**の追加 retry 上限です。
- `committing` 中断は `commit_outcome_unknown` として failed に保持し、自動再送しません。original は既存 saver を省略しないため ForceUpload します。手動 Retry では再送・重複の可能性があります。非公式 API に exactly-once guarantee はありません。
- restart はファイルの先頭から再試行します。byte offset を使った Google upload session resume は未実装です。
- cancel は best effort。Google に commit 済みの asset は削除しません。cancel と成功が競合した場合、確認できた成功を completed と表示します。
- Wi-Fi/charging は daemon が約5秒ごとに確認。制限に反すると実行中 request を中断し pending に戻します。Wi-Fi 検出は Network.framework の経路判定で、接続後の Google 到達性まで保証しません。
- 同じ内容でも異なる account / quality は別 job。同一 policy の completed 履歴を消すとローカル重複履歴は消えますが、upstream remote hash check は残ります。
- Live Photo の片方が既に remote にある場合は `remote_live_photo_component_exists` として停止します。完全なペアとして存在するかを推測せず、繰り返し自動再送しません。
- 元の写真ライブラリの asset は削除しません。completed / cancelled の daemon staging copy は削除します。

## セキュリティ

`/var/mobile/Library/Application Support/GoToHP/` は 0700、queue と credential は 0600。独立 daemon の credential はこの開発版では private JSON ファイルに保存し、Keychain 保存は未実装です。jailed の native account は email と account ID のみ保存し、トークンの取得・更新を Google Photos の既存 SSO に任せます。認証通信は TLS 検証を有効にし、credential や upstream の生の error / response は UI・ログへ返しません。

IPC の role は JSON から受け取りません。Settings と許可済み Google Photos は account/settings mutation、Google Photos / Photos は import/queue 操作が可能です。root / カーネル / 許可済みプロセスに別 tweak を注入できる攻撃者からの保護は提供しません。protocol は任意の filesystem path を受け付けず、daemon が生成した ID と検証済み basename だけを使います。

## Upstream 更新

```sh
bash scripts/sync-upstream.sh
# または監査済み commit を指定
bash scripts/sync-upstream.sh <commit>
```

submodule の commit と `GotohpCore/UPSTREAM_REVISION` を更新し、`.build/upstream` に iOS projection を生成します。本家ファイルは直接変更しません。変更内容・差分・テストを確認してから commit。projection の境界と IPA 調査は [docs/architecture.md](docs/architecture.md)、実機チェックは [docs/device-validation.md](docs/device-validation.md)。

高度な Google Photos 私有 UI hook、jailed のアプリ終了後の自動バックアップ、編集済み Live Photo の current representation、任意 device profile、Keychain、quota 自動検証はこの版に含みません。添付 IPA はリポジトリや配布物に含めていません。

## 表示言語

日本語・英語に対応しています。Google Photos のプロフィールメニュー → GoToHP の設定 → 表示 → 表示言語で、端末の設定／日本語／英語を選べます。端末の言語に対応する翻訳がなければ英語を使用します。言語の変更は GoToHP の画面に反映され、プロフィールメニューは次に開いたときに更新されます。

翻訳データは dylib に含まれるため、Sideloadly／LiveContainer に翻訳ファイルを別途入れる必要はありません。翻訳の追加方法は [localization.md](docs/localization.md) を参照してください。
