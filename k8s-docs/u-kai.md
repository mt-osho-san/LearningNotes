# コンセプト

> さらに、Kubernetes は単なるオーケストレーションシステムではありません。実際には、オーケストレーションの必要性はありません。オーケストレーションの技術的な定義は、「最初に A を実行し、次に B、その次に C を実行」のような定義されたワークフローの実行です。対照的に Kubernetes は、現在の状態から提示されたあるべき状態にあわせて継続的に維持するといった、独立していて構成可能な制御プロセスのセットを提供します。A から C へどのように移行するかは問題ではありません。集中管理も必要ありません。これにより、使いやすく、より強力で、堅牢で、弾力性と拡張性があるシステムが実現します。

ここが面白いところな気がする。Reconcile loop で気づいたらあるべき状態になっていると言うのが k8s な気がしている

- kube-proxy が実際にどうなっているのかは気になっているけど、調べられていない
  > ラベルは効率的な検索・閲覧を可能にし、UI や CLI 上での利用に最適です。 識別用途でない情報は、アノテーションを用いて記録されるべきです。 ラベル管理は使うエコシステムによっても変わってくる重要な概念 k8s のラベル管理のベスプラを知りたい。。。 ラベルにプレフィックスがあるとか知らなかった
  - `k8s.io/` とか `kubernetes.io/` とか...
- ラベルセレクターで、等価だけではなく不等や集合などで表現できるの知らなかったけど、表現方法がわからなかった
  - notin とか見たことない。。。
  - そもそもそれ以外、とかで選択したことがオペレーション上あまりないからかな？ 良く見たら表現方法あった
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

## Ephemeral Containers

> Ephemeral containers differ from containers in that they lack guarantees for resources or execution, and they will never be automatically restarted, so they are not appropriate for building application.
> Ephemeral containers may not have ports, so fields such as ports, livenessProbe, readinessProbe are disallowed.
> Pod resource allocations are immutable, so setting resources is disallowed.

> Ephemeral containers are useful for interactive troubleshooting when kubectl exec is insufficient because a container has crashed or a container image doesn't include debugging utilities.

- For Debugging

## Disruptions

> A PDB limits the number of Pods of a replicated application that are down simultaneously from voluntary disruptions.

- 下の例でもあったけどクォラムなどの、最少数の Pod が決まっている時には使うべしな感じ
  > Pods which are deleted or unavailable due to a rolling upgrade to an application do count against the disruption budget, but workload resources (such as Deployment and StatefulSet) are not limited by PDBs when doing rolling upgrades. Instead, the handling of failures during application updates is configured in the spec for the specific workload resource.
- ローリングアップデートの際には PDB は使われないので、ちゃんと Deployment などの設定で設定しましょう

- It is recommended to set AlwaysAllow Unhealthy Pod Eviction Policy to your PodDisruptionBudgets to support eviction of misbehaving applications during a node drain. The default behavior is to wait for the application pods to become healthy before the drain can proceed.

- AlwaysAllow を設定して、不正なアプリケーションをさっさと摘出できるようにすることがおすすめらしい

- PDB を適切にセットしておけば、誤った node の更新などによる Pod の不足を防ぐことができそう
- プロダクションで大事な Pod にはマストで設定しておくべきな気がする
- ただ、予期せぬ障害には耐えられないはず
- DisruptionTarget によって、事前に削除される前に理由を知ることができるってこと？
- ただし、何回も同じエラーになりそうなものに関しては、DisruptionTarget の理由として利用されないっぽい
- ただ、disruption は中断される可能性もあるようで、実際に削除されなかった場合は DisruptionTarget の理由は削除されるみたい
- Separating Cluster Owner and Application Owner Roles のところ意味わからんかった.PDB が責務わけに使えるってどういう意味？
- 一応 cluster administrator が PDB を設定する感じに見える

## Pod Quality of Service Classes

- QoS を設定することで、Node Pressure がある時にどの Pod を優先的に削除するかを決めることができる
- QoS のクラスは Guaranteed, Burstable, BestEffort の 3 つ
- 優先順は Guaranteed, Burstable, BestEffort の順なので逆の順番で削除されていく

> When this eviction is due to resource pressure, only Pods exceeding resource requests are candidates for eviction.

- resource pressure と node pressure は違うとみて良い？
- NodePressure に達しても削除選択されるし、自身の resource request を超えていた場合でも Pod が削除されると思って良い？

> For a Pod to be given a QoS class of Guaranteed:
> Every Container in the Pod must have a memory limit and a memory request.
> For every Container in the Pod, the memory limit must equal the memory request.
> Every Container in the Pod must have a CPU limit and a CPU request.
> For every Container in the Pod, the CPU limit must equal the CPU request.

- つまり, qos: Guaranteed みたいな設定ではなく、limit,request の値の操作によって決まるってことかな？

> Any Container exceeding a resource limit will be killed and restarted by the kubelet without affecting other Containers in that Pod.

- resource limit さえ付けておけばメモリリークとかがあっても殺してくれるので他の pod に迷惑かけづらかったりするのかな？

> The kube-scheduler does not consider QoS class when selecting which Pods to preempt. Preemption can occur when a cluster does not have enough resources to run all the Pods you defined.

- QoS とは別に Preemption があるのかな？

## User Namespaces

- idmap ってなんや
- user namespaces も新しい機能で、pod の host 内の権限管理とかか？

> User namespaces is a Linux feature that allows to map users in the container to different users in the host.

- つまり、linux の機能で、コンテナ内の User を host の User に紐づける機能？

> A pod can opt-in to use user namespaces by setting the pod.spec.hostUsers field to false.

- 結局 linux の機能なのか Pods の機能なのかよくわからんかった

## DownwordAPI

- 以下のような感じでデータを登録して、Pod 自身のデータにアクセスできる感じ?

```yaml
volumes:
  - name: podinfo
    downwardAPI:
      items:
        - path: "labels"
          fieldRef:
            fieldPath: metadata.labels
        - path: "annotations"
          fieldRef:
            fieldPath: metadata.annotations
```

## Deployment

> To see the Deployment rollout status, run kubectl rollout status deployment/nginx-deployment.

- 普通に知らなかった

> Do not overlap labels or selectors with other controllers (including other Deployments and StatefulSets). Kubernetes doesn't stop you from overlapping, and if multiple controllers have overlapping selectors those controllers might conflict and behave unexpectedly.

- 結構脆い.被らないようにしないといけないけど、被ってもなかなか気づかないとかありそう

> A Deployment's rollout is triggered if and only if the Deployment's Pod template (that is, .spec.template) is changed, for example if the labels or container images of the template are updated. Other updates, such as scaling the Deployment, do not trigger a rollout.

- rollout は Pod のテンプレートが変更された時だけ

> For example, suppose you create a Deployment to create 5 replicas of nginx:1.14.2, but then update the Deployment to create 5 replicas of nginx:1.16.1, when only 3 replicas of nginx:1.14.2 had been created. In that case, the Deployment immediately starts killing the 3 nginx:1.14.2 Pods that it had created, and starts creating nginx:1.16.1 Pods. It does not wait for the 5 replicas of nginx:1.14.2 to be created before changing course.

- 作成途中で変更があった場合は、途中で作成されたものは削除されて即座に新しいものが作成される

> It is generally discouraged to make label selector updates and it is suggested to plan your selectors up front.

- Label selector の変更は避けるべきで事前にちゃんと計画を立てるべき

- deployment が長期的に revision を持っていることは知らなかった

> CHANGE-CAUSE is copied from the Deployment annotation kubernetes.io/change-cause to its revisions upon creation. You can specify theCHANGE-CAUSE message by:

- CHANGE-CAUSE は Deployment の annotation からコピーされるらしい

> kubectl rollout undo deployment/nginx-deployment --to-revision=2

- 上のように戻せるのね
- ただ、CD の仕組みとか使っている場合はソースコードが SSOT だから結局はコードで示すことになりそうな気もする

> You can set .spec.revisionHistoryLimit field in a Deployment to specify how many old ReplicaSets for this Deployment you want to retain. The rest will be garbage-collected in the background. By default, it is 10.

- revisionHistoryLimit で保持するリビジョンの数を指定できる

> If you want to roll out releases to a subset of users or servers using the Deployment, you can create multiple Deployments, one for each release, following the canary pattern described in managing resources.

- canary したいなら二つの Deployment を作る必要あり
  - argo-rollouts とか使うのも手であるらしい

> All existing Pods are killed before new ones are created when .spec.strategy.type==Recreate.

## ReplicaSet

- ごちゃごちゃ書いてあるけど Deployment 使いましょう

## StatefulSet

- pv を使い回す
- pod の識別子もしっかりしている
- service は headless にすることで、特定の pod には同じ名前でアクセスできるようにする
  - ただし service なので、普通の名前解決と同じように使える

> When a StatefulSet's .spec.updateStrategy.type is set to OnDelete, the StatefulSet controller will not automatically update the Pods in a StatefulSet. Users must manually delete Pods to cause the controller to create new Pods that reflect modifications made to a StatefulSet's .spec.template.

- めんどくさそう。どういう時に利用するタイプなのか？

> When using Rolling Updates with the default Pod Management Policy (OrderedReady), it's possible to get into a broken state that requires manual intervention to repair.

> If you update the Pod template to a configuration that never becomes Running and Ready (for example, due to a bad binary or application-level configuration error), StatefulSet will stop the rollout and wait.
> In this state, it's not enough to revert the Pod template to a good configuration. Due to a known issue, StatefulSet will continue to wait for the broken Pod to become Ready (which never happens) before it will attempt to revert it back to the working configuration.
> After reverting the template, you must also delete any Pods that StatefulSet had already attempted to run with the bad configuration. StatefulSet will then begin to recreate the Pods using the reverted template.

- これあかんのでは？podTemplate を書き間違えてエラーにしてしまったら、podTemplate を更新して、手動で pod を削除しないといけないってこと？
- でも確かにこの状況に陥ることは多々あった

- PersistentVolumeClaim retention が新機能ぽいけど、Retention は今まで通りの機能で Delete が新しい機能っぽい

## DaemonSet

- spec.affinity.nodeAffinity で適切にノードに配置することができるっぽい
- って書いてあったのに、describe してもそのようなフィールドはなかった
- よくわからない

> You can add your own tolerations to the Pods of a DaemonSet as well, by defining these in the Pod template of the DaemonSet.

> Because the DaemonSet controller sets the node.kubernetes.io/unschedulable:NoSchedule toleration automatically, Kubernetes can run DaemonSet Pods on nodes that are marked as unschedulable.
>
> If you use a DaemonSet to provide an important node-level function, such as cluster networking, it is helpful that Kubernetes places DaemonSet Pods on nodes before they are ready. For example, without that special toleration, you could end up in a deadlock situation where the node is not marked as ready because the network plugin is not running there, and at the same time the network plugin is not running on that node because the node is not yet ready.

- どのノードにもスケジュールできるようにしている
- これにより、ノードが ready になる前に DaemonSet が配置されることがある
- これはネットワークプラグインが動いていないノードにネットワークプラグインを配置するためのものなどかな

## Job

> There are three main types of task suitable to run as a Job:

> Non-parallel Jobs
> normally, only one Pod is started, unless the Pod fails.
> the Job is complete as soon as its Pod terminates successfully.

> Parallel Jobs with a fixed completion count:
> specify a non-zero positive value for .spec.completions.
> the Job represents the overall task, and is complete when there are .spec.completions successful Pods.
> when using .spec.completionMode="Indexed", each Pod gets a different index in the range 0 to .spec.completions-1.

> Parallel Jobs with a work queue:
> do not specify .spec.completions, default to .spec.parallelism.
> the Pods must coordinate amongst themselves or an external service to determine what each should work on. For example, a Pod might fetch a batch of up to N items from the work queue.
> each Pod is independently capable of determining whether or not all its peers are done, and thus that the entire Job is done.
> when any Pod from the Job terminates with success, no new Pods are created.
> once at least one Pod has terminated with success and all Pods are terminated, then the Job is completed with success.
> once any Pod has exited with success, no other Pod should still be doing any work for this task or writing any output. They should all be in the process of exiting.

- よくわからん。。。

## Service, LoadBalancer, and Networking

> Pods can communicate with each other directly, without the use of proxies or address translation (NAT).

- NAT とかを使わずにダイレクトに Pod 同士が通信できる

> Agents on a node (such as system daemons, or kubelet) can communicate with all pods on that node.

> The Service API lets you provide a stable (long lived) IP address or hostname for a service implemented by one or more backend pods, where the individual pods making up the service can change over time.

- Service は安定した IP アドレスやホスト名を提供するためのものなので、Pod が変わっても問題ない

> Kubernetes automatically manages EndpointSlice objects to provide information about the pods currently backing a Service.

- EndpointSlice は Service にバックエンドとしている Pod の情報を提供するためのもの
- Service 作成時に自動で作成されるから、人間はあまり意識するものではないのかも(意識したことない)

> A service proxy implementation monitors the set of Service and EndpointSlice objects, and programs the data plane to route service traffic to its backends, by using operating system or cloud provider APIs to intercept or rewrite packets.

- いきなり service proxy とか出てきたけど何もん？
  - kube-proxy のことだった
  - ただ、Proxy とか使わないでいいんじゃなかったけ？
  - もう少し理解必要

> Kubernetes's model is that pods can be treated much like VMs or physical hosts from the perspectives of port allocation, naming, service discovery, load balancing, application configuration, and migration.

- これいい例えかも。VM とかのサイズをコンテナレベルにしただけみたいな。K8s 導入の説明とかでも使えそう

> For the other parts, Kubernetes defines the APIs, but the corresponding functionality is provided by external components,

- この Plugin 的なところが K8s の面白さ
- kube-proxy はデフォルトだけど、ものによっては他のものを使うこともできる

## Service

> Each Pod gets its own IP address (Kubernetes expects network plugins to ensure this).

- cni が Pod に IP アドレスを割り当てるのか

> Port definitions in Pods have names, and you can reference these names in the targetPort attribute of a Service. For example, we can bind the targetPort of the Service to the Pod port in the following way:

- 普通に知らなかった。いつもポート番号指定していたので、こっちの方がわかりやすいし、変更に強いかも

- あえて selector による指定をせずに Service を作成し、EndpointSlice の endpoints を手動で指定することで、Service を利用しつつも任意のアドレスに通信を行うことができるので、移行中や、別環境指定などの用途で利用できるみたい

> EndpointSlices are objects that represent a subset (a slice) of the backing network endpoints for a Service.

- Endpoints に紐づいている pod が 1000 を超えると切り捨てる？

> The mapping configures your cluster's DNS server to return a CNAME record with that external hostname value. No proxying of any kind is set up.

- ExternalName は DNS サーバーに CNAME レコードを返すように設定する Service なので、Service を使って外部のサービスにアクセスするときに使うのかな

> You can specify your own cluster IP address as part of a Service creation request.

- 手動設定も可能

- ExternalName の例で db の接続があったけど、確かに db に対して使えるな
- db はマネジどサービスでもそこまでの経路は k8s として管理可能になるって感じか

  - そしてうまくいけば db も k8s に乗せることができる

- ただし HTTP のような HOST を機にするやつに使うと予期せぬことがこったりするよとのこと

  - これはおそらく HTTPS の証明書とかでもエラーが起きるのじゃないかな？

- 環境変数に Service の IP とかが載っているのは知らなかった
- これは Docker Engine の legacy container links をサポートするためのもの？
- デプロイ順序とか気をつけないといけないみたいで、そもそも DNS に任せた方が良いのかも

> You can (and almost always should) set up a DNS service for your Kubernetes cluster using an add-on.

- ほぼ必須なので DNS サービスをセットアップしましょう

> A cluster-aware DNS server, such as CoreDNS, watches the Kubernetes API for new Services and creates a set of DNS records for each one.

- kubernetes API を監視して DNS レコードを作成している感じみたい

  - ってことは速攻で変更されるのかな？
  - DNS のキャッシュとかどうなるんだろう？
  - というか kube-proxy との違いが分からんくなってきたけど、DNS は service の名前解決で、kube-proxy は名前解決された service の ip をどこに転送するかのルールを設定するのかな？

- ExternalIPs は Service の IP に対して、外部からアクセスできるようにするためのものっぽい
  - ただ、k8s は Ip 割り当てとかを行わないので、IP が存在することは自分で担保しないといけない感じかな？

## Virtual IPs and Service Proxies

> Every node in a Kubernetes cluster runs a kube-proxy (unless you have deployed your own alternative component in place of kube-proxy).

> The kube-proxy component is responsible for implementing a virtual IP mechanism for Services of type other than ExternalName.

- ExternalName 以外の Service に対して仮想 IP を実装するのが kube-proxy の役割

> kube-proxy watches the Kubernetes control plane for the addition and removal of Service and EndpointSlice objects.

- DNS に任せるのはキャッシュは TTL があるので、変更が遅れることがあ理、Pod のようなすぐに死ぬようなものには向かない？

> Overall, you should note that, when running kube-proxy, kernel level rules may be modified (for example, iptables rules might get created), which won't get cleaned up, in some cases until you reboot.

- node の kernel level に対して変更を加える見たい
- iptables mode では Service の変更のたびに iptables にルールを追加するみたい

  - そして dnat して service に転送するみたいな感じ？

- etcd とかに IP アドレスを保存して、unique な IP アドレスを割り当てたり、k8s のコントロールプレーンが掃除をしているらしい

## Ingress

> Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

> You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect.

- annotation で 特定の機能を利用できるようにすることができるみたいだけど、ingress の controller によって機能が異なるので、ここは spec でカバーできなかったのか？と思うところ

- default ingress class という指定も可能らしく、ingressClassName を入れないとそうなるみたい

  - ただ、おそらく、ingressClass の annotation で default ingress class であることを指定するので、ingressClass が不要ということではないと思う

- と思ったけど ingress によっては default の定義なしで動くとか書いてあった

  - よく分からん

- defaultBackend というルールを適用せずに全てのリクエストを受け付けることもできるみたい
- service リソース以外に対しても resource として指定できるみたい
- TLS 終端前提で https のサポートが可能っぽい
  - ただし 443 ポートしか使えないっぽい

## Ingress Controllers

- Ingress 使うには Controller の設定が必要
- Ingress Controller の指定には IngressClass が使われる
  - IngressClass に ingressclass.kubernetes.io/is-default-class: "true" という annotation をつけることでデフォルトの IngressClass になる

## Gateway API

- Ingress の後継で、role ベースで、Ingress と違って、様々な責務がリソースごとに分離している
- また、header based matching や traffic weighting など、ingress ではれば annotation で個別対応するようなやつも対応できる

- GatewayClass と Gateway と XXXRoute のリソースで分かれている
- GatewayClass で controller を指定して、Gateway でエンドポイントを待ち受けて,Route でパスやヘッダーなどのマッチングで振り分ける

## EndpointSlices

> The EndpointSlice API is the mechanism that Kubernetes uses to let your Service scale to handle large numbers of backends, and allows the cluster to update its list of healthy backends efficiently.

- Service が大量のバックエンドを扱うための API で、クラスタが効率的にバックエンドのリストを更新できるようにするためのもの

> In Kubernetes, an EndpointSlice contains references to a set of network endpoints.

> The control plane automatically creates EndpointSlices for any Kubernetes Service that has a selector specified.

- selector が指定されている時だけなんか？

> By default, the control plane creates and manages EndpointSlices to have no more than 100 endpoints each. You can configure this with the --max-endpoints-per-slice kube-controller-manager flag, up to a maximum of 1000.

- これって、1000 個以上の Pod を冗長化のために利用したい場合はどうなるのか？

> Most often, the control plane (specifically, the endpoint slice controller) creates and manages EndpointSlice objects. There are a variety of other use cases for EndpointSlices, such as service mesh implementations, that could result in other entities or controllers managing additional sets of EndpointSlices.

- endpoint slice controller が管理しているが、service mesh などの実装によっては他のエンティティやコントローラが管理することもあり、管理している EndpointSlice に特定の label をつける必要があるみたい

- endpoint slice の変更は kube-proxy 経由で全ての node に達するので思い処理

- 難しくて、日本語にしてもよく分からんかった

- なんで endpoints が必要なのかが分からなかった。古い仕組みだからまだ依存している仕組みがあるのかな？

## Network Policies

- L3,L4 レベルのネットワーク制御の仕組み
- Pod が通信できるエンティティは 3 つの識別子の組み合わせによって識別される

  - 許可されている他の Pod
    - selector によって指定できるっぽい
  - 許可されている NS
  - IP ブロック

- NetworkPolicy は CNI によって提供されるので CNI がそもそも NetworkPolicy をサポートしている必要がある
- NetworkPolicy が同じ NS にあると、基本的に Pod は通信を拒否するみたい
- ポリシーは和集合で評価されるので、評価順序はポリシーの結果に影響しない

- policyType と ingress,egress というフィールドがあるけど、ingress,egress というフィールドで設定するならわざわざ policyType を設定する必要があるのかな？

- ipBlock の用途は外部サービス向けみたい

- podSelector の値を空にして全ての Pod を対象にし、policyTypes だけを指定すると、その policyTypes に対して全ての Pod に適用される

  - デフォルトで全て拒否みたいになる

- 上のポリシーの ingress に空を入れると、全ての 通信を受け付ける
- ポリシーは追加方式なので、他の NetworkPolicy が当たっている場合はそのポリシーも適用される
- なので、デフォルトのポリシーを設定しておくと、NetworkPolicy で明示的に指定されていない Pod に対してもポリシーが適用されるので良いよねみたいな感じ
- SCTP って何？

## DNS for Services and Pods

- namespace が同じなら service name で、違うなら、service_name.namespace_name で service の名前解決ができる

- srv レコードは名前付きポート向けに作成されるみたい
  - 名前付きポートって、yaml を解釈するときに実際に値をつけると思っていたけど、srv レコードを使って解決するものなのか？
- pod の dns は pod-ip.namespace.pod.cluster.local で解決される
  - これでも解決する必要ある？すでに ip が名前にあるやん
- 一応 pod の spec で hostname とか subdomain を指定でき、それが FQDN の要素になることもできるみたい

- Pod が利用する DNS サーバーなどの設定を dnsConfig で指定できるみたい

## IPv4/IPv6 Dual-Stack

- 名前の通りで、Pod ごとに v4,v6 のアドレスを持つことができるようになるみたい
- CNI やプロバイダーがそもそも対応していないと使えないっぽい
- プライベート IP が割り当てられる k8s において v6 を使えることって何が嬉しんんだろう？
- あんまり v6 のメリットがわからん

## Topology Aware Routing

- トラフィックの意地によるコスト削減やパフォーマンス向上が目的みたい
- EndpointSlice は Service の endpoint を計算する際に各 endpoint のトポロジー(region と zone)を考慮し、ゾーニ割り当てるためのヒントフィールドに値を入力する
- そして kube-proxy はこのヒントを利用して、近い endpoint を優先したりするようになるみたい

- 特的の annotation を auto にすると service に対して設定できて、トラフィックを発信元の近くにルーティングできるみたい
- 受信トラフィックが特定のゾーンに偏っている場合、この機能によりルーティングも偏ってしまうのでおすすめしないとのこと
- 1 つのゾーンに 3 つ以上の endpoint を持つ必要があるみたい

  - そうでないとルーティングに偏りが生じるみたい

- kube-proxy は endpointslice コントローラーによって設定されたヒントに基づいてルーティング先の endpoint をフィルター処理するみたいで、これによって、同じゾーン内の endpoint にトラフィクをルーティングできる

- セーフガードという概念もあるみたく、これらがチェックアウトされない場合は kube-proxy はゾーンに関係なくクラスター内のどこからでも endpoint を選択するみたい

- 制約事項もいくつかある

## Service ClusterIP allocation

- クラスターの DNS Service は Service の IP 範囲の十番目のアドレスらしい

- 確かにそうだった

```
kube-dns       ClusterIP   10.96.0.10      <none>        53/UDP,53/TCP,9153/TCP   6d21h   k8s-app=kube-dns
```

## Service Internal Traffic Policy

## Volume
