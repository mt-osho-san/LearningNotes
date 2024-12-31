# コンセプト

> さらに、Kubernetes は単なるオーケストレーションシステムではありません。実際には、オーケストレーションの必要性はありません。オーケストレーションの技術的な定義は、「最初に A を実行し、次に B、その次に C を実行」のような定義されたワークフローの実行です。対照的に Kubernetes は、現在の状態から提示されたあるべき状態にあわせて継続的に維持するといった、独立していて構成可能な制御プロセスのセットを提供します。A から C へどのように移行するかは問題ではありません。集中管理も必要ありません。これにより、使いやすく、より強力で、堅牢で、弾力性と拡張性があるシステムが実現します。

ここが面白いところな気がする。Reconcile loop で気づいたらあるべき状態になっていると言うのが k8s な気がしている

- kube-proxy が実際にどうなっているのかは気になっているけど、調べられていない
  > ラベルは効率的な検索・閲覧を可能にし、UI や CLI 上での利用に最適です。 識別用途でない情報は、アノテーションを用いて記録されるべきです。 ラベル管理は使うエコシステムによっても変わってくる重要な概念 k8s のラベル管理のベスプラを知りたい。。。
- ラベルにプレフィックスがあるとか知らなかった
  - `k8s.io/` とか `kubernetes.io/` とか...
- ラベルセレクターで、等価だけではなく不等や集合などで表現できるの知らなかったけど、表現方法がわからなかった
  - notin とか見たことない。。。
  - そもそもそれ以外、とかで選択したことがオペレーション上あまりないからかな？
  - 良く見たら表現方法あった
  ```yaml
  selector:
  matchLabels:
    component: redis
  matchExpressions:
    - { key: tier, operator: In, values: [cache] }
    - { key: environment, operator: NotIn, values: [dev] }
  ```

> 数人から数十人しかユーザーのいないクラスターに対して、あなたは Namespace を作成したり、考える必要は全くありません。 Kubernetes が提供する Namespace の機能が必要となった時に、Namespace の使用を始めてください。
> Namespace は名前空間のスコープを提供します。リソース名は単一の Namespace 内ではユニークである必要がありますが、Namespace 全体ではその必要はありません。Namespace は相互にネストすることはできず、各 Kubernetes リソースは 1 つの Namespace にのみ存在できます。
> Namespace は、複数のユーザーの間でクラスターリソースを分割する方法です。(これはリソースクォータを介して分割します。)
> 同じアプリケーションの異なるバージョンなど、少し違うリソースをただ分割するだけに、複数の Namespace を使う必要はありません。 同一の Namespace 内でリソースを区別するためにはラベルを使用してください。

- 結構 NS 切るつもりだったけど、そんなきらんで良いよってのがドキュメントの見解なんか？
- kube-node-lease と kube-public は良くわからん

> エンドユーザーのオブジェクトにアノテーションを追加するような自動化されたシステムコンポーネント(例: kube-scheduler kube-controller-manager kube-apiserver kubectl やその他のサードパーティツール)は、プレフィックスを指定しなくてはなりません。

- 自分で何かしらの Operator を作るときには、プレフィックスをつけるべきな気がした
- どこまで何をしたいかで annotation の付け方は変わりそうだけど、自動で付与するような仕組みがないと用意種類増やすのは大変そう

- Finalizers はリソースが残るよくある理由
- OwnerReference Controller のコード読むまで知らなかった概念
  - これを参照してうまいこと階層構造を達成している気がする

## Cluster Architecture

### Node

> This may lead to inconsistencies if an instance was modified without changing its name. If the Node needs to be replaced or updated significantly, the existing Node object needs to be removed from API server first and re added after the update.

> Pods that are part of a DaemonSet tolerate being run on an unschedulable Node. DaemonSets typically provide node-local services that should run on the Node even if it is being drained of workload applications.

- DaemonSet は Node が unschedulable でも動くようになっているのか

> Lease objects within the kube-node-lease namespace. Each Node has an associated Lease object.

- ここら辺気になる

> The third is monitoring the nodes' health. The node controller is responsible for:
> In the case that a node becomes unreachable, updating the Ready condition in the Node's .status field. In this case the node controller sets the Ready condition to Unknown.
> If a node remains unreachable: triggering API-initiated eviction for all of the Pods on the unreachable node. By default, the node controller waits 5 minutes between marking the node as Unknown and submitting the first eviction request.

- ここら辺面白い。5 分程度で Unknown になって、その後は Pod を削除するようになっているのか

> The node controller is also responsible for evicting pods running on nodes with NoExecute taints, unless those pods tolerate that taint. The node controller also adds taints corresponding to node problems like node unreachable or not ready. This means that the scheduler won't place Pods onto unhealthy nodes.

- taint によって node に対して Pod を配置しないようにしている

> That sum of requests includes all containers managed by the kubelet, but excludes any containers started directly by the container runtime, and also excludes any processes running outside of the kubelet's control.

- kubelet 以外で起動したプロセスは考えていないからね

- k8s の node は swap を off にする作業があったけど、feature gate でそれが on でも行けるようになる？
  - そもそも swap がなんで off じゃないといけないのかよくわかってない

## Communication between Nodes and the Control Plane

> Kubernetes has a "hub-and-spoke" API pattern. All API usage from nodes (or the pods they run) terminates at the API server. None of the other control plane components are designed to expose remote services.

- API server とのやりとりのみ

> especially if anonymous requests or service account tokens are allowed.

- 実は誰でもリクエストできる？でも認可されてないから認証プロセスはパスされても何もできない気もする

> Nodes should be provisioned with the public root certificate for the cluster such that they can connect securely to the API server along with valid client credentials.

- これって API server が node を認証するための root CA?それとも逆?(node が API server を認証するための root CA)

  > A good approach is that the client credentials provided to the kubelet are in the form of a client certificate.

- kubelet にクライアント証明書を使わせるのが良いみたい

> Pods that wish to connect to the API server can do so securely by leveraging a service account so that Kubernetes will automatically inject the public root certificate and a valid bearer token into the pod when it is instantiated.

> These connections terminate at the kubelet's HTTPS endpoint. By default, the API server does not verify the kubelet's serving certificate, which makes the connection subject to man-in-the-middle attacks and unsafe to run over untrusted and/or public networks.

- kubelet に通信するときは kubelet の証明書を検証しないので、中間者攻撃に注意
- 自分的には kubelet から API server に対して通信して、そこのコネクションがずっと続いているものだと思ってた
  - コネクションを API server から kubelet にはることって本当にあるのか？

## Leases

> Distributed systems often have a need for leases, which provide a mechanism to lock shared resources and coordinate activity between members of a set.

- 分散だから lock の仕組みが必要ってことかな？
  > Kubernetes, the lease concept is represented by Lease objects in the coordination.k8s.io API Group, which are used for system-critical capabilities such as node heartbeats and component-level leader election.
- 普通に知らなかった。。。おそらく、k8s のコアな部分で動いているものだから、普通に触れることはないのかもしれない
- 自分でカスタムコントローラーを作り、リーダー選出が必要なのであれば Lease を使うこともできるみたい

## Cloud Controller Manager

- Node, Route, Service Controller, などが あるみたい

## About cgroup v2

> The kubelet and the underlying container runtime need to interface with cgroups to enforce resource management for pods and containers which includes cpu/memory requests and limits for containerized workloads.

- ひとまず、今の k8s は cgroup v2 を使っていることが多いからバージョンアップしましょう

## CRI

> The Container Runtime Interface (CRI) is the main protocol for the communication between the kubelet and Container Runtime.
> For Kubernetes v1.32, the kubelet prefers to use CRI v1. If a container runtime does not support v1 of the CRI, then the kubelet tries to negotiate any older supported version. The v1.32 kubelet can also negotiate CRI v1alpha2, but this version is considered as deprecated. If the kubelet cannot negotiate a supported CRI version, the kubelet gives up and doesn't register as a node.

- 結構古い CRI までサポートしてくれているのかな

## Garbage Collection

> A namespaced owner must exist in the same namespace as the dependent. If it does not, the owner reference is treated as absent, and the dependent is subject to deletion once all owners are verified absent.
> if a cluster-scoped dependent specifies a namespaced kind as an owner, it is treated as having an unresolvable owner reference, and is not able to be garbage collected.

- cluster scope の時は何に使うん？

> After the owner object enters the deletion in progress state, the controller deletes dependents it knows about. After deleting all the dependent objects it knows about, the controller deletes the owner object.

> During foreground cascading deletion, the only dependents that block owner deletion are those that have the ownerReference.blockOwnerDeletion=true field and are in the garbage collection controller cache. The garbage collection controller cache may not contain objects whose resource type cannot be listed / watched successfully, or objects that are created concurrent with deletion of an owner object.

> The kubelet performs garbage collection on unused images every five minutes and on unused containers every minute. You should avoid using external garbage collection tools, as these can break the kubelet behavior and remove containers that should exist.

- unuse ってどうやって判定するの？

> Kubernetes manages the lifecycle of all images through its image manager, which is part of the kubelet, with the cooperation of cadvisor. The kubelet considers the following disk usage limits when making garbage collection decisions:

HighThresholdPercent
LowThresholdPercent
Disk usage above the configured HighThresholdPercent value triggers garbage collection, which deletes images in order based on the last time they were used, starting with the oldest first. The kubelet deletes images until disk usage reaches the LowThresholdPercent value.

- 上に書いてある感じだと、閾値に達したら古い順に削除していくみたい

> As a beta feature, you can specify the maximum time a local image can be unused for, regardless of disk usage. This is a kubelet setting that you configure for each node.
> To configure the setting, you need to set a value for the imageMaximumGCAge field in the kubelet configuration file.
> This feature does not track image usage across kubelet restarts. If the kubelet is restarted, the tracked image age is reset, causing the kubelet to wait the full imageMaximumGCAge duration before qualifying images for garbage collection based on image age.

- この値を設定しておいて、どんどんコンテナを破壊してセキュリティを保つとか？
- この値を利用するモチベーションを知りたいかも

## Mixed Version Proxy

- 複数バージョンの k8s を混在させるときに使うものらしい(知らなかった)

## Containers

> Usually, you can allow your cluster to pick the default container runtime for a Pod. If you need to use more than one container runtime in your cluster, you can specify the RuntimeClass for a Pod to make sure that Kubernetes runs those containers using a particular container runtime.

- RuntimeClass なんて知らなかった。いろんなランタイムを使いたい時とかってあるのかな？
  - より効率の良いものへの移行期間とか？

## Images

> If you don't specify a registry hostname, Kubernetes assumes that you mean the Docker public registry. You can change this behaviour by setting default image registry in container runtime configuration.

- デフォルトは Docker public registry なのか

- ImagePullPolicy Never っていつ使い道があるのかな？とも思うけど、ローカルで開発する時とかに、ローカルのテストしたいイメージを指定するとか？

> if you omit the imagePullPolicy field, and the tag for the container image is :latest, imagePullPolicy is automatically set to Always;

- latest って一回引っ張ってきたら更新されないものだと思っていたが、Always が設定されるから Pod が死んで入れ替わりが必要になったら更新されるのか
- やっぱ latest タグ指定ってだいぶ危険な気しかしない
- タグ指定しないのもの上と同じみたい

## RuntimeClass

> RuntimeClass is a feature for selecting the container runtime configuration. The container runtime configuration is used to run a Pod's containers.

- セキュリティとかめっちゃ頑張りたい場合の選択肢ってあったけど、コンテナランタイムの多様化とハードウェアレベルの仮想化の話とかがって、少し混乱
- 相当のことがないと使わない機能だとは思う
- もしくは、相当効率の良い CRI 準拠のコンテナランタイムが出てきて、乗り換え必須みたいにならない限りは

## Container Lifecycle Hooks

> This hook is called immediately before a container is terminated due to an API request or management event such as a liveness/startup probe failure, preemption, resource contention and others. A call to the PreStop hook fails if the container is already in a terminated or completed state and the hook must complete before the TERM signal to stop the container can be sent. The Pod's termination grace period countdown begins before the PreStop hook is executed, so regardless of the outcome of the handler, the container will eventually terminate within the Pod's termination grace period. No parameters are passed to the handler.

- 絶対に実行が完了するわけではないってこと？

> Enable the PodLifecycleSleepActionAllowZero feature gate if you want to set a sleep duration of zero seconds (effectively a no-op) for your Sleep lifecycle hooks.

- どういう目的？

> The PostStart hook handler call is initiated when a container is created, meaning the container ENTRYPOINT and the PostStart hook are triggered simultaneously. However, if the PostStart hook takes too long to execute or if it hangs, it can prevent the container from transitioning to a running state.

- entrypoint と同時に実行されるけど、hook が長い時間実行されているか、ハングしているとコンテナが起動していると見做されないみたい

> the hook(PreStop) must complete its execution before the TERM signal can be sent.

- prestop は制約きつめ？

> If either a PostStart or PreStop hook fails, it kills the Container.
> Hook delivery is intended to be at least once, which means that a hook may be called multiple times for any given event, such as for PostStart or PreStop

- 冪等大事

## Workloads

- 直接 Pod つかわずに workload resources を使いましょう

## Pods

- k8s 上の最小のコンピュートリソース

> You need to install a container runtime into each node in the cluster so that Pods can run there.

- 当たり前だけど、node にはコンテナランタイムが必要(いちいち node 準備するの大変)
  > Usually you don't need to create Pods directly, even singleton Pods. Instead, create them using workload resources such as Deployment or Job. If your Pods need to track state, consider the StatefulSet resource.
- Pod を直接作るな！例え 1 つでも
  > The name of a Pod must be a valid DNS subdomain value, but this can produce unexpected results for the Pod hostname. For best compatibility, the name should follow the more restrictive rules for a DNS label.
- DNS label による命名が良いらしい

> Static Pods are managed directly by the kubelet daemon on a specific node, without the API server observing them.
> for static Pods, the kubelet directly supervises each static Pod (and restarts it if it fails).
> The spec of a static Pod cannot refer to other API objects (e.g., ServiceAccount, ConfigMap, Secret, etc).

- kube-apiserver のコンポーネントなどを static pood で kubelet に直接監視させる
- kube-apiserver には監視はさせない。kube-apiserver との鶏卵問題なのかな？

## Init Containers

> Regular init containers (in other words: excluding sidecar containers) do not support the lifecycle, livenessProbe, readinessProbe, or startupProbe fields.

> If you specify multiple init containers for a Pod, kubelet runs each init container sequentially. Each init container must succeed before the next can run. When all of the init containers have run to completion, kubelet initializes the application containers for the Pod and runs them as usual.
> Init containers can run with a different view of the filesystem than app containers in the same Pod. Consequently, they can be given access to Secrets that app containers cannot access.

- これは知らなかった。init container は app container とは別のファイルシステムを持っていて、init containers 用の secret を使うことができる感じか
  > Because init containers can be restarted, retried, or re-executed, init container code should be idempotent. In particular, code that writes into any emptyDir volume should be prepared for the possibility that an output file already exists.
- これは確かに。冪等に作ってないと、途中までで失敗した init container が再度実行されたときに問題が起きる

  > Use activeDeadlineSeconds on the Pod to prevent init containers from failing forever. The active deadline includes init containers. However it is recommended to use activeDeadlineSeconds only if teams deploy their application as a Job, because activeDeadlineSeconds has an effect even after initContainer finished. The Pod which is already running correctly would be killed by activeDeadlineSeconds if you set.

- activeDeadlineSeconds は生きている Pod に対しても有効になってしまうから Job にだけ使いましょう

## Sidecar Containers

- Sidecar container っていう機能？デザインパターンではなく？
- 1.29 からの機能だから結構最近め
- init container によって表現するのが Sidecar container 機能？
- なんでわざわざ init container で実装しようとするのか？containers ではダメなん？
- と思ったら下に書いてあって、別に実行順序を気にしないなら containers で良いみたい。ただ、先に実行して欲しいなら init container をしようとのこと。あとはコンテナレベルの restart policy に対応していない古いバージョンに対しては init container しかないよねって感じかな？

> If an init container is created with its restartPolicy set to Always, it will start and remain running during the entire life of the Pod. This can be helpful for running supporting services separated from the main application containers.

- restartPolicy が Always だと、app のコンテナとともに sidecar として生き続ける

> If a readinessProbe is specified for this init container, its result will be used to determine the ready state of the Pod.

- startup probe が true になれば sidecar として生き続ける init container であっても次のステップに進むらしい
