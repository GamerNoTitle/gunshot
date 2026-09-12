# Google Photos のログイン中アカウントとメニュー

対象: Google Photos 7.92.0、jailed / Sideloadly / LiveContainer。

## 実機で報告された事象

ユーザーの同一 iPhone では Safari と注入なしの Google Photos でログインでき、Sideloadly の `Inject dylibs/frameworks` を有効にすると Google の認証画面が「安全性を確認できなかった」と拒否した。注入なしでログインした後、tweak を追加すると起動できた。

この比較は注入に伴う変更が関係することを示すが、GoToHP の特定フックと Sideloadly が追加するコードのどちらが原因かは未確定。今回の変更は Google の安全性判定を回避するものではない。既存のログインを保持して更新し、ログイン済みアプリを削除しない。

## メニュー

`PHSMyAccountMenuDataSource` の以下の既存カスタム項目 API に、1 セクション・1 行の「GoToHP の設定」を追加する。

| Selector | Encoding |
|---|---|
| numberOfCustomSectionsForAccountMenuViewController: | Q24@0:8@16 |
| accountMenuViewController:numberOfCustomItemsInSectionAtIndex: | Q32@0:8@16Q24 |
| accountMenuViewController:customItemAtIndexPath: | @32@0:8@16@24 |
| accountMenuViewController:performActionAtIndexPath: | v32@0:8@16@24 |

`OGLAccountMenuCustomItem.initWithTitle:icon:itemType:` の type=1 は、既存カスタムアクションの生成箇所 `0x100c0ca10` で確認した。元の項目とクリックは元実装へ渡す。全 ABI を確認してからまとめてフックする。Google Photos の UIWindow 上のフローティングボタンは削除し、jailed では UIWindow のフック自体を廃止した。設定はアカウントメニューのレイアウトに参加し、下部ナビゲーションに重ならない。

カスタムセクションと共通の設定・ヘルプ行の順序は Google Photos が決定するため、スクリーンショットで希望された「ヘルプの直下」と完全に同じ順序になるかは実機確認が必要。座標で強制配置しない。

## 認証経路

1. `PHSAccountManagerImpl.viewingAccount` の戻り値を変えず、既存 manager を weak 参照する。
2. `PHSAccount._ssoIdentity` の型を検証し、`hasValidAuth`、`userID`、`userEmail` から現在のアカウントのメタデータを取得する。
3. GoToHP を開くと jailed 版は `account_native` でこのアカウントを接続する。入力欄にトークンを貼り付ける必要はない。
4. Go core の `Api.BearerToken` は、native binding に対して C ABI provider を呼ぶ。
5. `photosSSOService.fetcherAuthorizerForAccountID:scopes:` から `photos.native` scope の既存 SSO authorizer を取得し、`authorizeRequest:completionHandler:` に Google Photos の HTTPS URL のリクエストを渡す。このリクエスト自体は送信しない。
6. native authorizer が更新した Authorization ヘッダーから bearer を受け取り、gotohp の API 呼び出しに使う。アカウント接続時は既存のリモート hash lookup により API が受け付けることを検証してから binding を保存する。

永続化するのは email と `gunshot_native_id` のみ。access token、refresh token、Cookie、Keychain の内容はファイルや診断ログに保存しない。Android master token への変換・ログインセッション全件抽出・認証 URL の書き換えは行わない。

トークン取得前後で現在の account ID とログイン状態を確認する。アカウント切り替え・サインアウト時には以前のキューを別のアカウントに送らず失敗させる。元のアカウントへ戻して GoToHP を開き、失敗したジョブを retry する。SSO はメインスレッドで呼び、Go の worker は最大 30 秒待つ。メインスレッドを待機させない。native token を得られなくても Android 認証へフォールバックしない。

## 制約と検証

- 自動接続は jailed の埋め込み core 用。独立 gotohpd はアプリ内 SSO provider を持たず、native binding を受け付けない。rootless/rootful daemon は従来の gotohp credential を使用する。
- Google Photos の内部 ABI と iOS token の API 互換性に依存する。実機の接続・upload・quota の確認前に成功を保証しない。
- Go tests: アカウント識別子、都度の provider 呼び出し、provider 不在、エラーの秘匿、ヘッダー改行拒否、従来 credential との分離。
- macOS native fixture: 既存 manager の取得、メインスレッド待機拒否、SSO callback、異なるアカウント、サインアウト、取得途中のアカウント切替。
- 実機: メニュー表示・位置・既存項目、ログイン済みアカウントの自動接続、JPEG 1 枚、期限切れ後の更新、再起動、アカウント切替と retry を確認する。
