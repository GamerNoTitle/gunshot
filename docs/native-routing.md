# Google Photos の標準バックアップ操作を GoToHP へ転送

**jailed 7.92.0 の新しい手動・自動バックアップ経路は [共通要求の連携](analysis/backup-routing.md) を参照してください。以下は rootful/rootless に残る従来の手動 UI フックの説明です。**

**対応範囲は Google Photos 7.92.0 の手動「今すぐバックアップ」操作です。自動バックアップを含む全アップロードの置き換えは未実装です。実機未検証。**

Google Photos → **GoToHP → Settings** に account、quality、queue の設定ページがあります。そこで account を追加・選択してから **Route Google Photos backup action** を有効にします。有効化時に GoToHP の送信先メールアドレスと対象範囲を表示します。Google Photos の automatic backup は別途 OFF にし、独立した標準アップロードとの重複を避けてください。

以後、対象となる Google Photos の標準バックアップ操作は選択 asset を GoToHP に渡して queue 画面を開きます。元の標準アップロード関数を呼びません。失敗時に標準アップロードへ戻す fallback はありません。成功・失敗と progress は GoToHP queue で確認します。Google Photos 内部の backup DB、サーバーのレスポンス、完了 callback を偽装しません。画質と送信先は GoToHP の設定を使用します。アカウント変更時は転送設定を OFF/ON して送信先を再確認する必要があります。

## 調査根拠

提供 IPA のメイン executable と GooglePhotos_GeneratedFramework の Mach-O Objective-C metadata を読み、次の method type を確認しました。バイナリ/逆コンパイル結果そのものは同梱しません。

| クラス | selector | encoding |
| --- | --- | --- |
| PHSBackupActionBehaviorImpl | backupLocalAssets: | v24@0:8@16 |
| PHSActionsGridModel | backupLocalAssets: | v24@0:8@16 |
| PHSLocalAsset | phAsset | @16@0:8 |
| PHSLocalAsset | isLocked | B16@0:8 |

実行時にも version、class、selector、encoding を全て照合し、一致したときだけ Objective-C method replacement を行います。未知の型・取得できない asset・locked asset は GoToHP のエラー画面に送ります。NSSet/NSArray の全件を解決してから処理するため、未対応 item の混在で一部だけ native へ送ることはありません。

これは公開 API の保証ではありません。別バージョンでは転送設定は unavailable になり、標準操作は Google Photos 本来のものです。更新後は routing が働くと想定せず、GoToHP の Upload を利用してください。自動バックアップ、共有時に発生する upload、locked folder、編集の保存、新規生成コンテンツなど、上記 action を通らない経路は対象外です。全経路を置換するには Swift/Scotty uploader と完了 model の実機解析が別途必要です。

## 実機 gate

- OFF 時に手動バックアップが本来の動作をする。
- ON 時、単一/複数選択と grid/one-up の対象 action で標準送信が開始されず、GoToHP に一度だけ queue される。
- credential 未設定/失効、daemon 停止、PhotoKit 拒否、disk full で標準経路へ再送されない。
- account 切替では旧送信先に送らずエラーになる。
- 未対応 version / selector では unavailable 表示になる。
- completed までは Google Photos のサーバー asset/backup 状態を勝手に更新しない。
- 自動バックアップ OFF の状態で、実際の Google quota と作成 asset を確認する。
