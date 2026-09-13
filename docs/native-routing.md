# Google Photos の標準バックアップ操作を GoToHP へ転送

jailed / rootless / rootful で、対応する純正の手動・自動バックアップ要求を
GoToHP に渡します。IPA の解析基準は **7.20.2 / 7.92.0** で、版番号を固定せず、
各機能が必要とする class / selector / 引数の型を実行時に照合します。
[処理と診断の詳細](analysis/backup-routing.md)。

1. Google Photos を起動し、ログイン中のアカウントへの自動接続を待ちます。
2. プロフィールメニュー → **GoToHP の設定**で画質を選び、
   **手動・自動バックアップを GoToHP へ送る**を有効化して送信先を確認します。
   この切替は既定 OFF です。
3. Google Photos の通常のバックアップボタンを使います。対応する操作は
   GoToHP の画面や毎回の確認を出さずにキューへ送ります。
4. 自動バックアップには Google Photos 本体のバックアップも ON にします。

元のスケジューラーと delegate を維持し、共通の `GMUAssetUploadRequest` /
`GMULivePhotoSingleUploadRequest` で PhotoKit 原本を転送します。Go の実際の
完了後に純正の fingerprint 照合を再開し、成功を確認します。GoToHP 単独の
アップロードも前景の完了監視で検知し、純正のアカウント別 fetchData による
表示更新を要求します。設定を開いたままにする必要や、毎回の再起動はありません。
通信とサーバー反映に時間がかかる場合はあります。

アカウント不一致・書出し失敗・再照合失敗では純正のデータ送信に戻しません。
Google Photos の DB、バックアップフラグ、成功結果を直接作り替えません。
画質と送信先は GoToHP の設定を使用します。送信先を変更した場合は転送設定を
OFF/ON して再確認してください。新規要求から有効なので、導入・切替前にすでに
始まっていた純正送信は対象外です。

jailed / LiveContainer では Google Photos を前面で開いてください。jailbreak では
原本が daemon のキューに渡るまで開き、その後は認証が利用できる間 daemon が
続行します。Google Photos が終了すると純正の新しい自動要求は作られません。
認証の更新にはホストが必要です。[認証の制約](analysis/native-account.md)。

旧手動 `backupLocalAssets:` の互換処理はソースに残りますが、共通要求の ABI が
不適合なら設定から手動・自動連携を新たに有効化できません。
locked folder・編集専用・共有専用など、任意の全経路の置換は保証しません。
[対応範囲と検証項目](full-upload-replacement.md)。
