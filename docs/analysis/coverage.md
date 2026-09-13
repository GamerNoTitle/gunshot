# 解析範囲・未解析部分

| 領域 | 現時点の状態 |
| --- | --- |
| App Info.plist | bundle / executable / version / minimum OS / Photos permission key 確認 |
| 2 image の ObjC class / instance method | metadata 全件索引あり。存在確認のみの項目が大半 |
| 手動 backup action | class / selector / encoding 確認、転送実装と mock test。実機未検証 |
| 自動 backup / legacy / Scotty | 対応する共通要求を両方式で転送し純正の再照合を実行。任意の全経路の網羅は未確認 |
| Native completion | 限定した 4 関数の selector call 追跡。完全な result schema 未確定 |
| Live Photo | gotohp source と PhotoKit export を実装。native pairing/commit/再生は実機未検証 |
| gotohp auth / API / quality | upstream source と projection を調査。実認証・quota は未検証 |
| Google Photos 内部認証 | credential の抽出や token dump は行っていない。native account と GoToHP の mapping 未実装 |
| Google Photos DB / native upload history | schema と mutation 全体は未解析 |
| Google Photos 私有 protobuf | 一部 selector / gotohp schema のみ。全 descriptor / wire format の解析ではない |
| Locked folder | entry metadata を確認。暗号化・鍵管理・保存先 semantics は未解析 |
| 編集 / CNDE / 生成コンテンツ | 関連呼出の存在を一部確認。全 pipeline は未解析 |
| アルバム / 共有 / partner sharing | metadata に名前が含まれても機能解析は未完 |
| 検索 / 顔認識 / Lens / memories / UI 全般 | 全機能の意味・挙動は未解析 |
| Extensions / background URLSession 再接続 | 全 executable と既存 session の実機追跡は未実施 |
| Swift-only / C / C++ / class methods / categories | 今回の instance-method 索引の対象外 |
| rootless / rootful / jailed パッケージ | CI build / layout / 依存検査済み。実機起動・Google通信は未検証 |

「未解析」は機能がない・安全・危険・非対応だと断定するラベルではありません。この索引だけから判断できないことを示します。今後の結果は [総合索引](index.md) から該当 document へ追記し、静的根拠・mock test・実機結果を区別してください。
