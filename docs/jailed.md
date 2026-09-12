# Jailed / sideload / LiveContainer

開発版。iOS 15+ / arm64 の GooglePhotos executable を対象にした、Go runtime 同梱の dylib です。添付 7.92.0 は iOS 18+。実機での Google Photos 再署名・LiveContainer 起動・Go runtime 共存・認証・アップロードは未検証です。

## 配布物とビルド

```sh
bash scripts/package.sh jailed
python3 scripts/verify-package.py jailed
```

`packages/jailed/` に次を生成します。

- `gotohp-tweak-jailed.deb`: IPA injector 用。jailed iOS が `.deb` を直接インストールできるという意味ではありません。
- `GunshotJailed.dylib`: 同じ deb から取り出した単体バイナリ。LiveContainer の tweak import 用。
- `ThirdPartyNotices.txt`: gotohp、Go runtime、静的リンクした依存モジュールの notices。

Go uploader と依存 Go モジュールは静的リンク済み。Substrate、ElleKit、RocketBootstrap、PreferenceLoader、外部 executable は不要です。iOS 標準 framework は OS のものを使用します。jailbreak 用の `Gunshot.dylib` / daemon と取り違えないでください。

## `.deb` ファイルをそのまま注入する（Sideloadly）

Theos / Xcode / Go はビルド済み成果物の利用には不要です。`.deb` は配布用 archive であり、iPhone が dylib として実行するファイルではありません。**注入ツールに `.deb` を渡すと、ツールが中の dylib を展開して IPA に組み込みます。手動で展開する必要はありません。** App Store からインストール済みの Google Photos に `.deb` を開くだけで注入できるわけではありません。

Windows / macOS の [Sideloadly 公式サイト](https://sideloadly.io/)は `.deb` / `.dylib` / `.framework` / `.bundle` の注入と、加工済み IPA の export を案内しています。

1. 復号済み Google Photos **IPA** をメインの IPA 欄に読み込みます。`.deb` を IPA 欄には入れません。
2. **Advanced Options** の **Inject dylibs/frameworks** などの tweak 注入項目を有効にし、追加ボタン（＋ / Add）で **`gotohp-tweak-jailed.deb`** を選びます。画面の表記はバージョンにより異なります。ファイル選択が `.dylib` のみに絞られていれば、対応形式 / すべてのファイルへ切り替えます。拡張子を `.dylib` に変更する操作ではありません。
3. 注入一覧に jailed deb が載ったことを確認します。同梱の `GunshotJailed.dylib` をさらに追加する必要はありません。
4. 直接インストールするなら接続 iPhone と Apple Account を指定して **Start**。自分の署名で再署名・サイドロードします。IPA を別の方法で導入する場合は export モードで加工 IPA を保存し、その導入先で必要な署名を行います。
5. 起動後 **Google Photos → GoToHP → Settings** を開きます。初回の信頼 / Developer Mode は [Sideloadly FAQ](https://sideloadly.io/faq) を参照してください。

Windows で Sideloadly が要求する Apple device 接続用の iTunes / iCloud 等は公式セットアップに従ってください。これは tweak の Theos / Go 依存とは別です。rootless / rootful deb は jailed 注入用ではありません。注入・署名が成功したことと、この tweak の実機動作が確認できたことも別です。

LiveContainer の Tweaks importer に直接入れる場合は、後述の **単体 `.dylib`** を使います。事前注入した IPA と外部 tweak の二重読み込みは避けてください。

## サイドロードの共通条件

1. 手元の復号済み Google Photos IPA に jailed deb を対応する IPA injector で注入するか、単体 dylib を app の Frameworks に配置して `@rpath/GunshotJailed.dylib` の `LC_LOAD_DYLIB` をメイン executable に追加します。単に zip にファイルを足すだけでは読み込まれません。
2. dylib を含むアプリ全体を自分の利用可能な証明書・プロビジョニングで再署名し、サイドロードします。ビルド時の ad-hoc 署名だけでは通常の iOS にインストールできません。
3. 注入対象は **メインの GooglePhotos executable のみ**。app extension、Apple Photos、別の arm64e-only executable へは注入しません。再署名で bundle ID を変えても executable 名は維持してください。
4. Google Photos を開き **GoToHP → Settings → Account** で uploader の認証情報を入力します。Google Photos 側のログインは流用しません。
5. GoToHP の Upload から写真を選択します。NSPhotoLibraryUsageDescription がホストに必要です。Google Photos 7.92.0 では存在を確認済みです。

署名済み IPA、証明書、Google Photos バイナリはこのリポジトリ・配布物に含めません。再署名で使えなくなる Google Photos 自体の機能までは修復しません。

## LiveContainer

[公式の tweak 手順](https://livecontainer.github.io/docs/guides/tweaks)に合わせて単体 dylib を使います。

1. Google Photos IPA を LiveContainer に取り込みます。
2. **Tweaks** タブで Google Photos 用の新しいフォルダを作成し、そこへ `GunshotJailed.dylib` を Import Tweak します。全アプリに読み込まれる root Tweaks には配置しません。
3. Google Photos の app settings → **Tweak Folder** をそのフォルダへ設定します。TweakLoader を無効にしないでください。署名は LiveContainer の手順に従い、必要なら Sign を実行します。
4. 起動後 **GoToHP → Settings**。アカウントと queue はその guest の Application Support/GoToHP に保存します。

`.deb` の直接 import は LiveContainer のこの手順には含まれません。外部 tweak と IPA 内への事前注入を重複させないでください。まず単一 guest / 単一 container で検証します。複数 Go runtime を含む tweak の同時ロード、multitask、実行中の data-container 切替は未検証です。guest ファイル選択に問題がある場合は[公式の app 設定](https://github.com/LiveContainer/LiveContainer#fix-file-picker--local-notification)を確認してください。

## Jailbreak 版との差

| 動作 | rootless / rootful | jailed / LiveContainer |
| --- | --- | --- |
| uploader | mobile launchd daemon | Google Photos プロセス内 |
| account/settings | Google Photos 内 + Preferences | Google Photos 内 |
| Go runtime | daemon に静的リンク | dylib に静的リンク |
| アプリを閉じる | キュー投入後は daemon が継続 | background 通知で upload を中断し pending に戻す |
| 再開 | daemon が実行 | foreground 復帰 / アプリ再起動後 GoToHP を開く |
| 保存先 | mobile の Application Support | host/guest の Application Support |
| iOS 以外の実行時依存 | jailbreak loader / RocketBootstrap / PreferenceLoader | 追加パッケージなし |

UIKit の background 制限を解除しません。Go HTTP は background URLSession に移管できないため、画面ロック・OS suspend・force kill 後の継続は提供しません。中断時のキャンセル処理が OS 停止に間に合わない場合でも、次回初期化で queue を復旧します。再送は先頭からで、commit 中断は結果不明として停止します。通知の処理は core queue 上なので認証・ディスク処理が終わるまで遅れる場合があります。

credential は sandbox 内の 0600 JSON で、Keychain は未実装です。ディレクトリは 0700、初回 unlock 後アクセス可能、backup 対象から除外します。同じアプリ/LiveContainer のコードとその管理者から隔離するものではありません。独立 daemon 用の外部 IPC は開きません。

## 実機検証

サイドロードと LiveContainer それぞれで、起動、Settings、認証、JPEG/動画/Live Photo、複数選択、Wi-Fi/充電条件、background 中断、foreground 復帰、force kill と再起動、期限切れ credential を確認します。GoToHP を一度開くまで uploader は初期化しません。Native routing は [native-routing.md](native-routing.md) の別項目として検証してください。
