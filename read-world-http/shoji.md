# 1 章　ブラウザは何をしているのか

- 基本的な HTTP のリクエスト、レスポンス内容についての解説をしている
- HSTS のデータベースがあることを知らなかった
  - HSTS 自体は http ヘッダに Strict-Transport-Security の項目を定義することで次回以降 https での通信をさせる
    - 初回は平文での通信になってしまう
  - HSTS のデータベース（リスト）というのは、正式には HSTS Preload というもので、そのリストに該当するページは初回アクセス時から https での接続をさせる仕組み
    - 主要ブラウザはほぼ対応している

---

# 2 　章　

- この章では HTTP/1.0 ができるまでの歴史と、HTTP/1.0 におけるメソッドやパスなどについて解説をしている
- HTTP/0.9 という名前ができたのは、HTTP/1.0 ができてからだったのか
- MDN はもともと Mozilla のものだったが、現在は Google や MS もコントリビュートしている
- HTTP/0.9 では、HTML 以外を送る想定がなかったり、新しい文書に更新したり、削除したりできなかった
- http ヘッダーの"x-"は私的な独自ヘッダーに利用しているが、「標準外のフィールドが標準になったときに不便が発生するため、2012 年 6 月の RFC 6648 で非推奨になりました」らしい
- メールとニュースグループは HTTP の祖先のようなもので、それぞれ MIME やフィールド、メソッドやステータスコードが受け継がれている
- canon が.canon のトップレベルドメインを持っているのか、canon は IT のイメージあまりなかったが当時は進んでいたのか？（google で canon 調べると canon.co.jp だった）
- キリル文字の і とローマ字の i など似た文字を使った攻撃をホモグラフ攻撃というらしい、名前あったのか
- dk 社もスパルタン仕様

---

# 3 章

- HTTP/1.0 の主にブラウザ側での動きを解説する。
- フォームの機能を使ってファイル送信を-d のかわりに-F とすることで実現可能
- サーバーからブラウザへの通信時の gzip などの圧縮はサーバー側で設定が必要？
  - もしくは特に設定せずとも圧縮している？
- セッションクッキーと永続クッキーの 2 つがあることを知らなかった
  - 永続クッキーはいつまで残るのか
  - ＝＞"Cookie に期限日が含まれていない場合は、セッション Cookie と見なされます"
  - デフォルトはセッションクッキーということか
- クッキーはリクエスト時に毎回付与されるので適切なサイズ、量のクッキーを使うことが通信容量の観点で良い
- localStorage, sessionStorage は同一オリジンでのみ利用可能なのですね。
- ベーシック、ダイジェスト認証のデメリット
  - リクエストごとに認証が必要、明示的なログオフができない、端末の識別ができない
- 代わりにフォームのログインとクッキーを使ったセッション管理を利用するケースがほとんど
  - ダイジェスト認証とは違い、ID、PASS を直接サーバーに送信するので SSL/TLS が必須
- 署名付きクッキーでデータの一時的な保存
  - サーバー側にデータ保存のしくみが必要ないが、クライアントが別々のデバイスから利用したら共有されない
  - 安易に使うとユーザビリティが悪くなりそう
- なにかの勉強で x-forwarded-for ヘッダの話があった気がするが、Forwarded で標準化されているのか
- Last Modified（更新日時によるキャッシュ）はキャッシュの利用を確認するためにもサーバーへのアクセスが必要なので、Expired が導入された
  - 地球の裏側だとキャッシュの確認だけで 0.2 秒、光の速度を感じる
- Cache control の max-age, private などでキャッシュを利用するかどうかを制御可能（HTTP/1.1~）
- Vary ヘッダーの存在は聞いたことがなかった
  - ユーザーやデバイスによって表示内容が変化する際の理由を示している
- Referer スペルミスなのか笑（Referrer が英語としては正しい）
- Referer でアクセス元の URL がわかるので、機密情報を GET パラメータにいれるのは良くない
- robots.txt のほうが優先されるが、meta タグのほうが細かい調整が可能（noindex, nofollow など）
  - robots.txt を知っていて設定しない場合はクロールされても何も言えない
- サイトマップ：ウェブサイトに含まれるページ一覧とそのメタデータを提供する XML ファイル
  - サイトマップって聞いたことあったがしらなかった
- Google のガイドライン「同一コンテンツをすべてのブラウザに配信し、必要な設定を選ばせるレスポンシブデザインが推奨」
  - user-agent で表示内容を変えるもんかと思っていたが、推奨ではないということか

# 5 章

- HTTP/1.1 以降の機能について紹介
- 主な変更点として、通信の高速化、TLS による暗号通信、新メソッド追加など
- 以前は毎回コネクションを張るためにハンドシェイクをしていたが、keep-alive はこれを削減することで、通信速度の向上
  - ブラウザの同時接続数の推奨値が 4 => 2 に下がるというのはどういうこと？
  - ブラウザ１つに対して４つくらい接続していないと通信が遅いということ？
  - 接続を切るにはヘッダに Connection: Close を付与するか、タイム・アウトするか
  - 持続時間はクライアント、サーバー両方もっており、Frefox115s, nginx75s, apache15s
- パイプライニングはレスポンスを待たずにリクエストを送るというものだが、対応していないサーバーが多かったり、レスポンスの順序が大事なのっで HoLB が発生したりで、使われることはほとんどなくなった
  - が、HTTP/2 でストリームという機能として生まれ変わった（@ 8 章）
- アルゴリズムを秘密にするのではなく、アルゴリズムを公開しても暗号化ができることが大事
- TLS は接続の確立時に公開鍵暗号を使って共通鍵を作る。それ以降は共通鍵で通信をすることで安全性とスピードの両立
- 最も長い場合の TLS 接続にかかる RTT
  - TCP で 1.5, TLS ハンドシェイクで 2RTT, HTTP のリクエストで 1RTT => 計 4RTT (TCP の最後と TLS の最初は一緒にできる)
  - この往復を減らすために keep-alive やセッション再開機能、PSK などがある
- 鍵交換の方法、暗号化、署名方式などをまとめて暗号スイートという
- TLS はサーバークライアント間が信頼できない通信路でも安全、一方でブラウザ上のクラッキングなどは対処できない
- サーバー経由でクライアント同士がチャットする仕組みもがあるのか（この場合はサーバーの中は秘匿されない）
  - どういうアプリで使うのか
- ACME プロトコル初めて聞いた（自動証明書管理環境）
  - Let's Encrypt の無料の証明書サービスで利用されている
- 証明書の種類の話セキスペであったなあ
  - 今はもうブラウザ上での表示がかわることはないのか（TLS かどうかしか気にしない）
- 1.1 では PUT と DELETE, Options, trace, connect, path が追加された
  - Options は利用可能なメソッドを返す、が多くのサーバーでは有効にされていない
  - connect は HTTP のプロトコル上に他のプロトコルのパケットを流せる（主に HTTPS を中継する目的で使われる）
- アップグレードは、HTTP から別のプロトコルへアップグレードできる機能
  - HTTP ＝＞ TLS、Websocket、HTTP2 へ
  - 現在はそもそも TLS 前提なので HTTP2 では削除されている機能
- チャンクはデータを一括で送るのではなく、小分けにして行う。
  - 生成 AI で使われる＝＞ WebSocket だと思っていた
- データ URI スキームでは、URI がデータそのものになる

# 6 章

- HTTP/1.1 の時代になると、HTML を取得するだけのプロトコルから汎用的な用途に変化していった。
  - 本性では 1.1 以降に拡張されたプロトコルや規約を使った様々な事例を紹介
- Content-Disposition フィールドの指定によって、ブラウザで表示するのか、ダウンロードするのかを変える
- a タグで、downdload を指定すると、クリックした際にダウンロードするように矯正可能
  - マルウェアをダウンロードさせるのにも使われそう
- 複数範囲のユースケースは、キャッシングされていない部分だけ取得するとか、大きなファイルを順次ダウンロードするなどで利用される
  - キャッシュされている部分がどこかってどうやって確認してるんだろうか
- JS の XMLHttpRequest は、XML はほとんど関係ないが XML 処理用ライブラリにいれるための言い訳として XML がついている
- Form と比べると、送受信時に HTML がロードされないことや、キーと値が 1:1 になっている必要がないため様々なフォーマットで送受信可能だったりする
- 既存の仕組みで双方向通信できるようにしたのが Comet、WebSocket では最初からそれを想定して作られた
- HttpOnly 名前ややこしい、HttpOnly はクライアントのスクリプトからアクセスできなくする、Secure は HTTPS 通信の場合のみ Cookie が利用可能
- GeoLocation はクライアントが計測する方法と、サーバー側で推測する方法がある
  - skyhook の自動車走らせる方法は、後から追加されたアクセスポイントは対応していないってこと？
  - radiko は、Chrome 拡張機能で現在位置を変更できるものがある。
- RPC は、別のコンピュータの機能をあたかも自分のコンピュータ内であるかのように呼び出しを行う方法
- SOAP は HTTP の中に見に HTTP のような SOAP ヘッダ、SOAP ボディという構造を持つ。
  - SOAP は可搬性を重視するあまり複雑度が増してしまった
  - JSON-RPC はシンプルさを重視して、コンパクトにしている
  - この辺の技術は今はほとんど使われていないもの？
- WebDAV は HTTP を拡張して分散ファイルシステムとして使えるようにしたもの
  - 同期型であり、ネットワークがなければファイル一覧を取得できない（GDrive などはローカルにコピーを持っていて、必要に応じて同期）
- ケロベロス認証：ID とパスワードで AS から TGT をもらう。TGT を使って各サービス用チケット発行
  - 主に Windows で利用されて、ドメインへの参加が必須
- 現在は OIDC がデファクトスタンダード
- JWT：JSON をベースにして改ざん防止の署名を加えたもの。汎用的な仕組みだが、認証認可でよく使われる
- ヘッダー、ペイロード、署名をピリオドで接合したもの
- 意図的に署名アルゴリズムを none に上書きされないようにしないと、セキュリティホールになる
- Google Photo の共有機能は 40 字の英数字で、10 奥人のユーザーが１万枚ずつ入れても、1 ０の 58 乗書いアクセスすると１枚くらいだれかの写真を見れるというくらい
  - とはいえずっと同じ URL を使うと漏洩のリスクがあるので、期間限定するなど必要
- セキュリティホールを発見したときには securiy.txt から連絡先を見つけて報告（一般に公開されると攻撃に使われる）
- 短縮 URL や QR コードは基の URL を隠蔽するので注意が必要

# ７章

- エラーが出る

```
openssl req -new -sha256 -key ca.key -out ca.csr -config ./read-world-http/chapter4/openssl.cnf
Can't open "./read-world-http/chapter4/openssl.cnf" for reading, No such file or directory
```

- クライアント認証のユースケース意識したことなかったが、DC 内の通信や IoT などで使われるのか。
- チャンクは go の場合、最初からサポートされているので意識せずに利用できる。

# 8 章

- ALPN では TLS ハンドシェイク後に利用可能なプロトコルを共有してプロトコルを選択
- ALPN では TCP コネクションを再利用するので、UDP の HTTP3 は利用できない
  - そこで HTTP Alternative Services は同一サービスが別オリジンで動作していることを示して、そちらに誘導することで UDP を利用できるようにしている
- DNS の HTTPS レコードは、接続開始時点から利用可能なプロトコルを DNS レコードとして返せるので、より早い時点でプロトコルが決定する
- HTTP2 の前身は SPDY で Google が作成した
  - Google は Web サービスとブラウザの両方を抑えているので大規模な検証が可能
- HTTP2 の改善点は次の通り
  - ストリームにより、バイナリデータを多重に送受信可能
  - フィールドの圧縮
- ストリーム
  - HTTP1.1 まではひとつのリクエストが TCP ソケットを占有するので、ひとつのオリジンサーバーに対して 2~6 の接続を使っていたが、ストリームでは１つの TCP 接続の内部に仮想の TCP ソケットを作成し、利用。
- HTTP1.1 はフィールドの終端を見つけるまで逐次読み込んでいたが、HTTP2 ではバイナリ化されており、レスポンスの戦闘にフレームサイズが入っているので、受信側の TCP ソケットのバッファをすばやく空にできるのですぐに次のリクエストが可能
- フローコントロールによって、ストリームの通信料制御を行い、処理速度差が大きい機器間でデータを送りすぎることを予防する
- プリロード：link タグ、link ヘッダーフィールドによって HTML 本体をダウンロードする前に関連リソースのダウンロードが可能。
- HPACK：フィールドの圧縮方式、フィールドでは決まった名前や結果がよく出るので辞書として持っておく。
- SPDY が HTTP2 になったように、HTTP3 は QUIC が前身。
- HTTP2 は TLS なので高機能だが、パフォーマンスは落ちる。
  - HTTP3 では UDP を使うことで、アプリ層で TLS の機能を賄っている。（ネゴシエーション、輻輳制御など）
  - それにより、初回でも 1 往復の通信でネゴシエーションしたり、再接続では 0RTT で再送できる
  - HTTP2 では TLS と重複していた機能があったが、これを簡略化している。
- 従来はモバイル通信と WIFI が切り替わったりすると、5tuple によって別のコネクションとして認識されてしまうが、QUIC では通信経路が変わってもコネクション ID が維持される。
- HTTP2 からの変更はストリーム ID が 31->62 ビットに増えて上限まで使い切って切断されるリスクが減った、各フレームがストリーム ID とフラグを持たなくなったなど。
- HTTP3 ではサーバープッシュやストリームの優先度といったほとんど使われない機能の削除もされた。
- JS 用の通信 API
  - Fetch API:CORS の取り扱いが制御しやすい、キャッシュの制御可能、送受信ともストリーム可能
  - Server-sent Events：HTML5 の機能ひとつ、サーバーから任意のタイミングでクライアントにイベントを通知できる
  - WebSocket: オーバーヘッドの小さい双方向通信を実現、相手が決まってるので送信先などの情報は持たない（ステートフル）
  - WebRTC:ブラウザーサーバー間だけでなく、ブラウザ同士の P2P でも使われる。主に UDP が使われる。
    - ユースケース：ビデオ通話システム、スクリーン共有、ファイル交換、IP 電話端末、
  - Web Transport：WebSocket の弱点をカバーしている（非 TLS 通信を行う可能性がある、HoL ブロッキングがある）
  - HTTP ウェブプッシュ：ウェブサイトで通知機能を提供する仕組み（送った時点でブラウザが起動していなかったり、オフラインでも通知を遅れる）
    - Service Worker というサーバーとブラウザの間にあるプロキシサーバーのようなものを使う。

# 9 章

- CSS ピクセル（ブラウザの論理解像度）と物理的な解像度の比をデバイスピクセルレシオという
  - 高精細なデバイスがでてきて従来の 1px の枠内にそれ以上の px が入るようになっている
  - レスポンシブデザインはブラウザ側ではなく、サイト側が表示を制御するので、拡大縮小をブラウザにさせないために meta タグを追記する。
- 従来は、IE の対応が進まないこともあり、JPEG、PNG、GIF の３つがほとんどだったが最近はいろいろなフォーマットが対応されている
  - WebP: 可逆、非可逆の両方に対応し、アニメーションにも対応
  - AVIF: WebP よりも 1.75 倍サイズが小さく、1 ピクセルあたりの色の解像度が 10 ビットのダイナミックレンジにも対応
- セマンティック Web：テキストや文書ではなく、意味を扱えるようにするもの
  - ページに含まれる情報などを XML、JSON で扱ったり、CHAT−GPT で扱ったりしている。
- マイクロデータ：HTML に埋め込み可能なセマンティックの表現形式で、Event, Person, Product などの分類がある
- JSON-LD: schema.org に掲載されているデータの一つで、今後一番使われるようになると言われている。
  - データ形式：パンくずリスト、サイト名、記事、レシピ...
- RSS(RDF Site Summary): ウェブサイトの更新履歴のまとめに関するボキャブラリー、ブログやウェブサイトを更新するとコンテンツ管理システムが自動で更新する。未読のエントリーを集めて効率よく閲覧できるようにしている。
- その他のデータ形式：vCard は連絡先交換フォーマット、iCalendar はスケジュール、ToDo の交換用フォーマット
- オープングラフプロトコル: SNS で使われるメタデータで、リンクを貼り付けたときに記事の一部が引用される仕組みに使われる
  - これをベースに Twitter が作った Twitter カードもある
- QR コード：デンソーが開発したもので数値としては 7000 桁まで対応可能、商品などのトレーサビリティに対応しようとするとバーコードでは対応負荷だが、QR ならできる。
  - 誤り訂正レベルも変えられるのか
- QR コードの対応スキーマ
  - URL、メールアドレス、WIFI 設定、vCard など
- Deeplink: ブラウザからモバイルアプリへ遷移する仕組み
- HLS（HTTP ライブストリーミング）: apple が作ったストリーミングの仕組み
  - 適切な解像度の動画が選択可能、字幕の切り替えにも対応
  - プロトコルが HTTP なので特殊な設定やサーバーが必要ないメリットが有る一方、ブラウザではサポートされていない環境が多い

# 11 章

- Dropbox は REST ではなく RPC を使っているらしい。
  - REST はパスが名詞、RPC は動詞（GET /1/files, POST /1/files/download）
- RESTful API では URL を通して情報のやり取りをするので URL 設計が重要
  - RPC もそうでは？
- クライアントから見ると、まとめて処理したい複数の対象があるときに、それに相当する API を一つだけ呼び出せばよいというのが理想的
  - 実際には LSUDs(Large Set of Unknown Developers) がいる場合、細かいユースケースに対応するには粒度の細かい API を作らざるを得ない
  - 高レベル API、低レベル API みたいなのか
- JSON RPC の例では、REDIS において、MULTI 命令をするとシングルスレッドなので他の命令を割り込ませずに簡単なトランザクションとして扱える
- 一貫性を担保するためにサーバー側でトランザクションを自作する方法もある
  - サーガ：実現したい機能を小さなトランザクションを保つ機能に分割し、リソースを長時間ロックしないようにするもの
- HETEOAS(Hypermedia As The Engine Of Application Stat): インターフェースの一般化を仕様化したもの
  - リソース間の関連情報やリソースの操作のリンクをレスポンスに含めてリソースの自己記述力を向上させる。
- REST-ish: URL に動詞が入ったり、バージョンが入ったり、フォーマットを表す文字がはいると REST とは言えないという人もいる
  - バージョンもだめなのか。
  - よく見る気がする。並行して複数バージョンをサポートしたいなら仕方ない（MS の例）し、一般公開している API ならそうするのが普通な気がする。
- メソッドの安全と冪等
  - 安全：実行してもリソースを変化させない
  - 冪等：サーバーのリソースは変更されるが、何度実行しても結果が変わらない
  - 安全ならば冪等である
- GET において冪等ではない操作に使ってはだめ。
  - ガレージのドアを操作する API を GET で作ると、プレビューなどでも操作されてしまう。
- ユーザーを返す API でユーザーがいなかったときに 404 なのか、空で 200 なのか。
  => リソースが 0 件であることと、リソースがそもそも存在しないということを分けて考える (https://qiita.com/YuyaAbo/items/a8b4b055a3d9dbeffcf3)
- rateLimit の IP アドレス単位で実行する場合は、サーバーはどうやって送信元 IP を取得しているのだろうか。

# 12 章

- ブラウザが HTTP アクスセスをするのは、ウェブサイトのロードか、その後の JS でのリクエスト。
- XMLHttpRequest: IE が Fetch API に対応していなかったり、Axios というラッパーが使われることもあったが、今後はより高機能で使いやすい Fetch が使われることになり、あまり使われなくなっていくらしい。
- Fetch API: サーバーから通信を行う際に利用、1 回繋いでおわりではなく、コネクションが張られ続け、サーバー側から何度もレスポンスを返すことができる
- WebSocket: HTTP はフィールド部が大きいので、小さいデータのやり取りには向いていない。一方 WS ではそれを克服し、初回のクライアントからの接続をすればその後は双方向通信ができる
- Fetch API: 標準化された API で XMLHttpRequest にある機能は全部使え、それに加えキャッシュの機能などの細かい操作も可能
  - Cors まわりなどで XMR に比べ、デフォルトでセキュアな設定になっている
  - リダイレクトをたどる、たどらない、エラーにするなどの制御も可能
  - Service Worker 対応している
    - ブラウザーとサーバーとの通信に介在しプロキシサーバーのように振る舞う。
    - 別スレッドでバックグラウンドで動く、オフライン時にキャシュしておいた情報を使うなど
- ハンドラーは開発者が作成するロジックが含まれる部分
  - 開発者が書くコードほとんどハンドラーということ？
- セッションデータの保存方式として、クッキー、DB、メモリなどの種類がある
  - 複数のデバイスから利用する場合はクッキーだと同期できないので、DB ということ？
- SSR: サーバー側で HTML を組み立てて、それを返す
  - リクエストだけ見ると、静的 HTML との違いはない
- Ajx: 画面をクリアせずに Web ページを読み込んだり、なんども更新する。Asynchronous JavaScript XML の略
  - 最初は HTML、JS はサブの立ち位置で、jQuery でちょっとしたコード書くくらいだったが、フロント側でやることがどんどん増えてきた。
- SPA: ほぼからの HTML に対して JS で差分更新していく
  - 配信にはどの URL にリクエストが来てもトップと同じ HTML ファイルを返す設定が必要
  - カーソルがきて、クリックされる前にコンテンツをサーバーにリクエストすることもあるらしい
- SPA + SSR: SPA は大量の JS を読み込むまでに時間がかかることがある。初回の表示のみサーバーで行い、表示されるまでの待ち時間が短くなる
  - Netx.js, Nuxt.js が該当。名前ややこし
- Python や Ruby では同時に動作するスレッドが 1 つに限定されていることがあるので、サーバーとして運用するには並列化するために複数のプロセスを起動する必要がある
  - nginx などで一旦リクエストを受けて、裏側で複数スレッド動かすというやり方がある
- cgi : common gateway interface 聞くけどなにか知らなかった
  - クライアントからのリクエストに応じて、外部プログラムを呼び出してその結果を http を介してブラウザに送信する仕組み
  - python とかを裏で呼び出してその結果を反映した html 返すってことか
- 開発環境モードで本番運用するとクレデンシャルなどが漏れる可能性もあるのでだめ
  - エラーがどこででたのかなどの情報も脆弱性につながる
- CGI: リクエストを受けるたびにプロセスが起動して、処理が終わったらプロセスが終了するので重い。起動しっぱなしにする fastCGI のようなものが使われることになる
- リライト初めて知った。
  - リバースプロキシが、リクエストを書き換えて適切なところにルーティングする

# 14 章

- サービスディスカバリに使えるレコードがあるのはしらなかった (SRV レコード)
  - 他のレコードとは違い、ポートまで含めることができる
- HTTPS を使っていても UDP の DNS を使っていればその内容からアクセス先がわかってしまっていたが、DoH (DNS over HTTPS) により通信のすべてを保護できるようになった
  - DNS over TLS にくらべ、DoH は通常の通信に紛れ込ませることができるのでより安全らしい
- リバースプロキシと一言でいっても、CDN、API ゲートウェイ、ロードバランサーなどがある。
- CDN は、通信の高速化やユーザーに近い場所でのコンテンツ配信に加え、高機能化が進んでいる
  - コンテンツをユーザーの近くに置くのがメインかと思っていたが、AS をショートカットもしていたのか。
  - DDoS 対応でオリジンサーバーを守ることやアクセス元の IP や国を制限など
- Cache Control では min-fresh というのもあるらしい。(鮮度維持期間が指定された時間以上残っていればキャッシュを送信)
- 開発時にキャッシュされたものなのかどうかを判断するために使われる Cache-Status フィールドというのもある
- private や no-cache の設定を謝ると、別のユーザーのプライベートな情報が表示されてしまうこともある
- ヘルスチェックに Liviness Prove, Readiness Prove の 2 種類あるのはしらなかった
  - サービスの起動だけを確認するのか、実際の機能を提供できるのかを確認するのかの違い。
- 分散トレーシングは初めて聞いたが X-Ray のようなサービスことだった。
  - どの処理がどの順番で行われているのか、どのくらい処理時間がかかっているかを見ていくもの

# 15 章

- OpenSocial は google と myspace が作成した SNS 向けの共通 API
  - FB や Linked in など様々なサービス内で利用できるアプリを開発する際に、移植作業が必要にならないようなもの
- Electron はウェブの技術でデスクトップアプリを作成できる。

# 16 章

- XSS は他のさまざあな攻撃の起点になるという意味で危険度が高い
  - たとえば、投入されたスクリプトからクッキーにアクセスされて漏えい等
- XSS の防衛方法は、出力前にサニタイズ(エスケープなど)をしたり、URL を言語の文字列結合機能ではなく、専用の処理系を使ったりすること
- クッキーの漏洩を防止するためには httpOnly で JS からアクセスできないようにするなど
- Content-Security-Policy ヘッダーフィールド
  - ウェブサイトで使える機能を細かく On/Off できる機能で、XSS のように JS が想定外の動作をすることを抑制
  - XSS の切り札となるが強力すぎて正常な動作も妨害する可能性がある＝＞セキュリティは利用しやすさとトレードオフになることも多い
- Mixed Content: HTTP へのアクセスが混じっているとエラーになる。
  - csp で upgrade-insecure-requests を有効化すると http と書かれていても https で取りに行くなどもある
- Cors は API サーバーを守るための機能だったのか。ブラウザかと思っていた。
- セッションハイジャッキング：セッショントークンを盗み出して、利用するとログインしているものとして ID,パスワードなしでもアクセスされてしまう
  - XSS や MITM 攻撃などで盗まれるので、HTTPS 化したり、httpsonly などを利用することで対策
- 昔はセッションの管理に端末固有の ID を利用していたが、これは個人情報の観点からよくなかった
- XSRF はログイン状態のユーザーに罠のサイトにアクセスさせて、操作をさせるもの
  - 対策：隠しフィールドにランダムに作成したトークンを埋め込み、post のリクエストを受け取るサーバー側で正しいトークンが含まれていないものは拒否
  - SameSite 属性で、リクエストを送信するときのページが同一サイトにない限りはクッキーを送信しなくなる
- クリックジャッキングは IFRAME を利用しており、よく使われるウェブサイトを透明にするパターンと、よく使われるサイトをしたにして、その上に悪意のあるサイトを透明に表示するパターンが有る。
- リスト型はバレたらどうしようもないので、パスワードマネージャー使うのが良い
- 最近は平文を保存せずに、忘れた場合は再発行というのがほとんどなのだろうか。
- ソルトを使わない hash 値を保存している場合は、ハッシュ値が同じになる値を突き止めたら終わり？
- CloudWatch でもログのマスク化の機能があるらしい
- TOTP の検証は前後のタイムボックスも許可されていることがあるのか
- パスキー最近良く見るけど仕組みわかっていなかった。
  - サービスがチャレンジを生成、クライアントは生体認証で秘密鍵を取り出して署名して、サービスが署名を検証
- GeoLocation を使って、普段とは別の場所からのログインは一旦保留にするなどもあるらしい
