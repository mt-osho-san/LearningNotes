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

- 基本は emptyDir
  - Pod が削除されると削除されるけど、Node がバックアップされている場合は削除されない？？
  - emptyDir.medium が Memory の場合は tmpfs で作成され、高速だが、ノードのリブートで削除されると、対比のように書かれていたため
- hostPath は host のファイルをマウントするのでセキュリティリスクあり
- host 上に作成されたファイルやディレクトリは特権コンテナか、ファイルのパーミッションを変更する必要がある
  - コンテナのホスト上の userid とかって指定できるんだっけ？
- local ボリュームがよくわからない。hostPath との違いは？

  - pvc かどうかってこと？
  - nodeAffinity を設定する必要があるらしい

- nfs ボリュームってのもあるのね

  - このデータ自体はどこにあるのか？特定の Node にあるのか？

- というか、ボリュームの種類が多すぎてよくわからん

  - これは Copilot の補完笑同じ気持ち

- PersistentVolume のとこ見ると、クラスター管理者は様々な用途向けの pv を用意する必要があるみたいなこと考えていて、なかなか大変だな

- StorageClass を使えば動的プロビジョニングできる
- DefaultStorageClass を有効化するには API サーバーのフラグを変更する必要があるのか？

  - そもそもフラグをコマンド区切りで追加するってことは Default という名前だけど、Default で選択されるものではない？

- PV と PVC は 1 対 1 の紐づき
- PVC を Pod が使っていると、PVC を削除しても Pod が PVC を使用しなくなるまで削除されない
- StorageClass をからにして、volume 指定、pv 側でも calimRef を指定すると pv の予約ができるポイ
- ものによっては pv を拡大できるっぽい
- ただ、拡張が失敗すると、手動切り戻しが必要になるっぽい

## Configurations

> Don't specify default values unnecessarily: simple, minimal configuration will make errors less likely.

- なるほど。いらんことはするなってことか

- yaml 1.1 では yes,no,on,off,true,false が使えるってのは驚き

## ConfigMap

- 容量は 1MB まで
- data と binaryData がある

  - どちらも key-value
  - binaryData は binary を base64 エンコードされている

- namespace またぎで使うことはできない？？？

  - 共通の config とかありそうっちゃありそうだけどな

- ConfigMap の値が変わると自動でマウントされている値も変わる
  - ただし、キャッシュなどの遅延は考慮すること
  - また、環境変数として設定した場合は、Pod の再起動が必要

## Secrets

- secret はデフォルトで暗号化されずに etcd に保存される
- Pod を作成できるのであれば secret をマウントすることもできる
- 安全に使用したければ

  - 暗号化
  - RBAC でのアクセス制御
  - 特定コンテナのみの Secret アクセスの制御
  - 外部 SecretStore の利用
    - ただ、これしてしまったら k8s の美味さがないのでは？

- secret には組み込みのタイプがあって、それに合わせてデータ作成とかしてくれるっぽい？
- imagePullSecrets に secret を入れれば private な registry からイメージを pull できるっぽい

## Liveness, Readiness, and Startup Probes

- LivenessProbe は いつコンテナをリスタートするか決めるもの

  - コンテナ自体は生きているが、デッドロックなどで止まっているのを検知する

- ReadinessProbe はコンテナが準備ができているかどうかを検知する
- startupprobe を設定すれば、こいつが成功するまで、livenss,readiness は評価されない
  - liveness,readiness と違って、この probe は一度限りしか実行されない

## Resource Management for Pods and Containers

- cgroup で cpu と memory を制御する感じ
- 制限をコスト OOM エラーでプロセスを終了させるみたい
- API Resource と、cpu,memory の違いが書いてあったけどよくわからん
- hugepages もよくわからん

  > コンテナがメモリー制限を超過すると、終了する場合があります。

- つまり終了しない場合もあるってこと？

> コンテナは、長時間にわたって CPU 制限を超えることが許可される場合と許可されない場合があります。 ただし、CPU の使用量が多すぎるために、コンテナが強制終了されることはありません。

- ここら辺もよくわからん
- feature gate を on にするとローカルストレージの使用量を測定できる？
- ローカルストレージのリクエストと limit をかけることも可能っぽい
- 拡張リソースの話は全くわからん

## kubeconfig

- kubeconfig ファイルの評価順が載っている

  - 困ったら見ると良いかも

- proxy も使えるとのこと
  - 前職が懐かしい。。

## Security

- Cloud,Cluster,Container,Code の 4C でセキュリティを考える

## Pod Security Standards

- Pod に対しては Security Context を指定することでセキュリティを強化できる
- ポリシーの項目では禁止すべき一覧が書いてあり、わかりやすい

  - host プレフィックスや privileged,capabilities は on にしたり、追加したりするなって感じかな
  - こういうルールを PaC とかでやれたらいいのかな〜

- AppArmor とか SELinux とかよく出てくるけどあまり理解していない

  - これらのフィールドに対しても制限するべきことが書いてある

- 攻撃対象を縮小するため/proc のマスクを設定し、必須とすべきです。の意味がわからなかったけど、GPT 曰く、Unmasked という値を設定すると、/proc の値がみれるみたいなので、よくにらしい
- Seccomp はシステムコールの制限を行うもので、それを禁止にするようなことはするなという感じ

> ポリシーの定義とポリシーの実装を切り離すことによって、ポリシーを強制する機構とは独立して、汎用的な理解や複数のクラスターにわたる共通言語とすることができます。

- 実装は別でやれよってこと？
  - 実装であった Pod Security Policy は廃止されている
  - Pod Security Admission か 3rd party でやりましょうって話みたい

## Cloud Native Security

- この章はそれぞれのステップでどのようなセキュリティを考えるべきかが書いてある
- ファジングやカオスエンジニアリングのようなセキュリティテストも重要
- ResourceQuotas の定義ってどうやってギリギリいっぱいいいところを見つけるのかな？
  - こういう取り組みって挑戦的で面白そう
  - 監視をうまいこと戦略的にしていくしかない？

> 異なるノード間でワークロードを分割します。 Kubernetes 自体またはエコシステムのいずれかからノードの分離メカニズムを使用して、異なる信頼コンテキストの Pod が別個のノードセットで実行されるようにします。

- まさにそうではあるけど、分離すべきものを定義するのがむずそう

  - どのような観点でノード分離すべきなのかな？
  - 何も考えなかったら様々なノードに様々な Pod が配置されるけど、それじゃまずいのってどんな時だろ

- 暗号化キーはハードウェアセキュリティモジュールに保存するのが良いらしいく、セキュリティキーを他の場所にコピーすることなく暗号化操作を実施できるとあるけどなんで？

  - セキュリティ的に良くなるのはわかる

- サービスメッシュとか使って mtls で通信暗号化したら、他のセキュリティ対策はいらないのかな？
  - アプリケーションの通信は全て http でも良い？

## Pod Security Admission

- PodSecurityPolicy は 1.25 で廃止されているので、その後継

> Pod のセキュリティアドミッションは、Pod の Security Context とその他の関連フィールドに、Pod セキュリティの標準で定義された 3 つのレベル、privileged、baseline、restricted に従って要件を設定するものです

- 名前空間ごとに admission controller を設定するみたい
- label を指定することで、どのレベルのセキュリティポリシーを適用するかを指定できる
- 以下のような感じで設定できるみたい

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-baseline-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.32

    # We are setting these to our _desired_ `enforce` level.
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.32
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.32
```

> ポリシーに違反した場合は、ユーザーへの警告がトリガーされますが

- 上のように書いてあるが、ユーザーへの警告って何？kubectl で操作した時に警告が出るのかな？
- ポリシー適用の除外もできる

  - 除外リストを静的に書く必要がある
  - 認証されていないユーザー名って書いてあったけど、認証されていないのにユーザー名ってどうやってわかる？

  > ほとんどの Pod は、ワークロードリソースに対応してコントローラーが作成します。つまり、エンドユーザーを適用除外にするのは Pod を直接作成する場合のみで、ワークロードリソースを作成する場合は適用除外になりません。 コントローラーサービスアカウント(system:serviceaccount:kube-system:replicaset-controller など)は通常、除外してはいけません。そうした場合、対応するワークロードリソースを作成できるすべてのユーザーを暗黙的に除外してしまうためです。

  - ってことはユーザー名による除外はほとんど意味がない？

- 数は少ないが、フィールドが更新されてもポリシー適用が無視されるフィールドもあるみたい

## ServiceAccount

- 人間以外のアカウントで、Pod や、クラスター内外のエンティティは ServiceAccount を使って認証することができる
- 各 namespace に対して default という名前の service account が自動で作成される
- RBAC が有効の場合はデフォルトの権限を与える？
- namespace の default service account を削除すると自動で service account オブジェクトを作成するとあるので、default は事実上消せないのかな
- 内部から k8sAPI にアクセスする場合や、外部のシステムからアクセスする場合に使えるみたい

  - また、内部から外部にアクセスする時も使える？(GitHub Actions の OIDC 連携みたいな？)

- Role を付与すると RBAC を達成できる

  - 上でいっている RBAC とは違うのかな？

- TokenRequest API や、ServiceAccountTokenVolumeProjection を使うことで、認証情報を取得することができる
  - projection の方であれば、kubelet によって自動で更新されるから楽なのかな？
- ServiceAccountSecret のやり方は非推奨

  - 静的な secret は使わないほうがいい

- TokenRequest は外部からでも使える？？ただ、認証情報取得するものなのに、外部のように認証しずらいものにどうやって渡すのかな？鶏卵みたいになるのでは？
  - おそらく、内部のワークロードで TokenRequest をして、その結果を外部に渡すような使い方をするのかな？
- 外部のシステムを認証する場合は証明書の認証か独自実装した Webhook 認証を使いましょうとのこと
- Service Account は署名された Jwt を使用して認証するみたい

> 1. トークンの署名を確認します。
> 1. トークンが期限切れかどうかを確認します。
> 1. トークン要求内のオブジェクト参照が現在有効かどうかを確認します。
> 1. トークンが現在有効かどうかを確認します。
> 1. オーディエンス要求を確認します。

- 上の手順、2 までしかわからん。オブジェクト参照とかオーディエンス要求って何？

  - gpt に教えてもらった

  ```
      手順	何を確認するか？
    ✅ 1. 署名を確認	トークンが正しく署名され、改ざんされていないか。
    ✅ 2. 期限切れか確認	exp フィールドのチェック（トークンが期限切れでないか）。
    ✅ 3. オブジェクト参照を確認	ServiceAccount が削除されていないか。
    ✅ 4. トークンの有効性を確認	Kubernetes の内部管理上、トークンがまだ有効か。
    ✅ 5. オーディエンスを確認	aud (audience) が API の要求と一致するか。
  ```

- 外部サービスなどが ServiceAccount の正当性を k8sAPI に問い合わせるときの推奨は TokenReviewAPI
- OIDC と違って、ServiceAccount が無効になったり、対象の Pod が死んだ時はそれを検知して即座に無効な値を返す
- 独自のトークンを発行し、Webhook トークン認証を使用するとかもできるみたい？
  > SPIFFE CSI ドライバープラグインを使用して、SPIFFE SVID を X.509 証明書ペアとして Pod に提供します。
- SPIFFE ってセキュリティのプロトコルの規格みたいな感じだったような気がするけどなんもわからん笑
- isito などのサービスメッシュで証明書も使えるよねということ

  - ServiceAccount を使うと K8s に負荷がかかるからそこは確かに心配だった
  - そもそも k8s を認証基盤として使うのは違うと思うし

> Device Plugin を使用して仮想 Trusted Platform Module (TPM)にアクセスし、秘密鍵を使用した認証を許可します。

- このやり方は渋い

## Controlling Access to the Kubernetes API

- TLS を使って k8sAPI にアクセスするのが基本
- その際の証明書の発行は private CA など引数で渡せる

- アクセスは、認証、認可、AdmissionControl の順で評価される

> While Kubernetes uses usernames for access control decisions and in request logging, it does not have a User object nor does it store usernames or other information about users in its API.

- ではどうやって認証する？署名とかを使うってこと？

- 認可モジュールには ABAC,RBAC,Webhook があるみたい
- 複数選択すると、複数で評価されるみたい
- AdmissionControl はリクエストの変更と拒否ができるみたい

- Auditing もあるみたいで、security 関連や時系列のレコードを提供してくれるみたい

## Role Based Access Control Good Practices

> system:unauthenticated グループのバインディングを確認し、可能であれば削除します。 これにより、ネットワークレベルで API サーバーに接続できるすべてのユーザーにアクセスが許可されます。

- アクセスが許可されて良いの？

- Secret への get 系を許可すると、secret の中身が見れるので、注意
- Pod などのワークロードリソースを作成する権限を渡すと、Secret,ConfigMap,PersistentVolume などの Pod にマウントできる他の多くのリソースへのアクセスが暗黙的に許可されるらしい。。。

  > 特権付き Pod を実行できるユーザーは、そのアクセス権を使用してノードへのアクセスを取得し、さらに特権昇格させる可能性があります。 適切に安全で隔離された Pod を作成できるユーザーや他のプリンシパルを完全に信頼していない場合は、ベースラインまたは制限付き Pod セキュリティ標準を強制する必要があります。

- 確かに...

> 誰か、または何らかのアプリケーションが、任意の PersistentVolume を作成する権限を持っている場合、そのアクセスには hostPath ボリュームの作成も含まれており、これは Pod が関連づけられたノードの基盤となるホストファイルシステムにアクセスできることを意味します。 その権限を与えることはセキュリティリスクとなります。

> PersistentVolume オブジェクトを作成する権限を許可するのは、次の場合に限定するべきです:

> ユーザー(クラスター運用者)が、作業にこのアクセスを必要としており、かつ信頼できる場合。
> 自動プロビジョニングのために設定された PersistentVolumeClaim に基づいて PersistentVolume を作成する Kubernetes コントロールコンポーネント。 これは通常、Kubernetes プロバイダーまたは CSI ドライバーのインストール時に設定されます。

- なるほど
- 信頼できる場合、ってのが面白い笑いきなり性善説

- escalate 権限を持っていると、特権昇格ができるので、これは注意が必要
- bind も、権限をバインドできてしまうってことかな？
- impersonate は他のユーザーになれるってことらしいけど、原理が全くわからん
- 「CSR の作成」と「CSR の承認 (Approval)」を両方できるユーザーは、新しいクライアント証明書を好きなだけ作れる。ってこと？

> validatingwebhookconfigurations または mutatingwebhookconfigurations を制御するユーザーは、クラスターに許可された任意のオブジェクトを読み取ることができるウェブフックを制御し、ウェブフックを変更する場合は許されたオブジェクトも変更できます。

> Namespace オブジェクトにおいて patch 操作を実行できるユーザーは(そのアクセス権を持つロールへの namespace 付きの RoleBinding を通じて)namespace のラベルを変更できます。 Pod のセキュリティアドミッションが使用されているクラスターでは、ユーザーは管理者が意図したより緩いポリシーを namespace に設定できる場合があります。 NetworkPolicy が使用されているクラスターでは、ユーザーは管理者が意図していないサービスへのアクセスを間接的に許可するラベルを設定できる場合があります。

- 確かに。。label でセキュリティや機能を制御することは多いので、これは注意が必要

--- 3-7

> クラスター内のオブジェクトを作成する権限を持つユーザーは、etcd used by Kubernetes is vulnerable to OOM attack で議論されているように、オブジェクトのサイズや数に基づいてサービス拒否を引き起こすほど大きなオブジェクトを作成できる可能性があります。 これは、半信頼または信頼されていないユーザーにシステムへの限定的なアクセスが許可されている場合、特にマルチテナントクラスターに関係する可能性があります。

- これも確かに。オープンに公開できるものではないな。。。簡単にぶっ壊せそう
- 抜け道が多くてなかなか大変。組み込みの PaC とかあればいいな

> 使用しなくなった場合には、etcd が使用する永続ストレージを削除するかシュレッダーで処理してください。

- シュレッダー？笑

> Kubernetes Secrets Store CSI Driver は、kubelet が外部ストアから Secret を取得し、データにアクセスすることを許可された特定の Pod に Secret をボリュームとしてマウントする DaemonSet です。

- ExternalSecrets はしっていたけど、直接外部ストアから取得するのは初めて知った
  - ただ、これだと Secret への API アクセスはどうなるのかな？
  - Pod にマウントしたらそれっきり？そもそもマウントするのか？

## Multi-tenancy

- tenant ってチームのコンテキストだったり、顧客のコンテキストだったりするっぽい

  - 後者しか知らなかった

- 強力な分離はセキュリティ的には良いけど、運用コストとかはかかるからそことの比較検討が重要

> In fact, a common practice is to isolate every workload in its own namespace, even if multiple workloads are operated by the same tenant. This ensures that each workload has its own identity and can be configured with an appropriate security policy.

- やっぱり ns でわけたほうが良さそう
- ns を分けることで、権限管理も細かくできるようになる
- Resource Quota でリソースの制限もしっかりやらないと node のシェアとかはできない
- これも ns でわけられる

> Quotas cannot protect against all kinds of resource sharing, such as network traffic. Node isolation (described below) may be a better solution for this problem.

- ネットワークのポリシーも ns などで厳格に制御しましょう
- L7 のサービスメッシュで制御したらなお良いよね

- pv は動的プロビジョニングで取得して、node リソースに紐づけるのはやめましょう
- テナントごとに StorageClass を設定することで分離を強化できる

- サンドボックス化というものがあるのか
  - これは手法自体ないろんな実装があって、こういうプラクティスをすることで、信頼できないリクエストを安全に処理できるって言いたいのかな？

> While controls such as seccomp, AppArmor, and SELinux can be used to strengthen the security of containers, it is hard to apply a universal set of rules to all workloads running in a shared cluster. Running workloads in a sandbox environment helps to insulate the host from container escapes, where an attacker exploits a vulnerability to gain access to the host system and all the processes/files running on that host.

- なるほど。AppArmor とかは強力だけど、おそらく node が対象だから、これら全てを適用するのはむずいので、サンドボックス化することで、コンテナのエスケープを防ぐってことかな
- gVisor ,Kata Containers などがあるらしい

  - syscalls を userspace kernel でやってしまうのかな？

- node 隔離の方がサンドボックスかされたコンテナよりも課金の考慮が簡単だったり、互換性やパフォーマンスの問題も少ないので実装が簡単
- node selectors を使うのはわかるけど Virtual Kubelet って何？
- QoS を k8s で定義できるから、顧客へのプランもうまいことできる
- ネットワークの QoS をかけとかないと、帯域を共有して食い潰す可能性がある
- ストレージの QoS はパフォーマンス特性の異なるストレージを作れるので、コスト最適化やワークロード最適化ができる
- Pod の優先順づけもでき、これによって、リソースが枯渇している時に、優先的にスケジュールしたい Pod を設定できる

> For example, CoreDNS (the default DNS service for Kubernetes) can leverage Kubernetes metadata to restrict queries to Pods and Services within a namespace.

- これはしらなかった。ただ、こういうのどこまでやった方が良いのかなと思ってしまう
  - NetworkPolicy や L7 の認可だけではダメ？
  - おそらく、名前解決できないだけで、ip アドレス直打ちしたら通じる
  - それであれば NetworkPolicy とか L7 で制御していればよくないか？
  - DNS 封じは管理コストにしかならないのでは？

> There are two primary ways to share a Kubernetes cluster for multi-tenancy: using Namespaces (that is, a Namespace per tenant) or by virtualizing the control plane (that is, virtual control plane per tenant).

- Virtual control plane とな。。。

> Control plane virtualization allows for isolation of non-namespaced resources at the cost of somewhat higher resource usage and more difficult cross-tenant sharing. It is a good option when namespace isolation is insufficient but dedicated clusters are undesirable, due to the high cost of maintaining them (especially on-prem) or due to their higher overhead and lack of resource sharing. However, even within a virtualized control plane, you will likely see benefits by using namespaces as well.

- 占有クラスタと ns の間って感じか

> it is a best practice to give each namespace names that are unique across your entire fleet (that is, even if they are in separate clusters), as this gives you the flexibility to switch between dedicated and shared clusters in the future, or to use multi-cluster tooling such as service meshes.

- これって、クラスタが違くても同じ ns 名であれば、その中のリソース名は一意であれって事?

- HNC というものがあるみたいで、ns を階層的に整理できう r のかな
- マルチチーム、マルチ顧客シナリオで役に立つみたい

  - ちなみに顧客ごとに ns 分ける？それだとやりすぎだから plan ごとに分けるのかな？

- Kubeplus というマルチ顧客テナント向けのツールがあるらしい
- Capsule はマルチチームテナント向け

## Hardening Guide - Authentication Mechanisms

- Client 証明書を使ったユーザー証明書は本番用途では適さない(ただし、kubelet では使っているみたい？)

  > Client certificates cannot be individually revoked.
  > Using client certificate authentication requires a direct connection from the client to the API server without any intervening TLS termination points, which can complicate network architectures.

        - なるほど。

- 静的トークンも適さない
- Bootstrap token は node が join する時に使うもので、これも適さない

- ServiceAccount や TokenRequest API Token はトークンの取り消し方法がないので、ユーザー認証には推奨されない s、資格情報を安全に配布するのも難しい

- k8s は OIDC サポートしているが、考えるべきこともある

  - OIDC 認証をサポートするためにクラスタにインストールされたソフトウェアは、高い権限で実行されるため、一般的なワークロードから分離する必要があり
  -

> Webhook token authentication is another option for integrating external authentication providers into Kubernetes. This mechanism allows for an authentication service, either running inside the cluster or externally, to be contacted for an authentication decision over a webhook. It is important to note that the suitability of this mechanism will likely depend on the software used for the authentication service, and there are some Kubernetes-specific considerations to take into account.

- OIDC に関わらず、認証サービスと連携できるけど、一から作り込む必要がありそう...
- しかもコントロール p るえーんのファイルシステムへのアクセスが必要みたいで、マネージドサービスだときついかもらしい
- できたとしてもめちゃ強い権限のサービスになるから、セキュリティ的には厳しい

> Another option for integrating external authentication systems into Kubernetes is to use an authenticating proxy. With this mechanism, Kubernetes expects to receive requests from the proxy with specific header values set, indicating the username and group memberships to assign for authorization purposes. It is important to note that there are specific considerations to take into account when using this mechanism.

- ヘッダーだけに依存するようになるから webhook よりも簡単で権限も不要？？
- ただ、ヘッダーなんて誰でも変えられるから、気をつけろやとのこと。確かに

  - 署名は必要だな

- そもそも、ユーザーを認証したい時ってどんな時？開発者が k8s にアクセスする時とかってこと？
- そして、結局何が良いのか？OIDC が無難かな
- EKS とかだと、AccessEntity というやつで、IAM と K8s の Role を紐づけることができるから、これを使えば良い気がする

## Kubernetes API Server Bypass Risks

- Static pods は特定の dir や url から kubelet が作成するかつ、kubeapiserver は関与しないので、特定 dir への攻撃が可能な場合はシャドーな pod が作成される可能性がある
- Static Pod は他のオブジェクトへのアクセスが制御されているらしいが、hostPath などをマウントできるのでそこから攻撃できる

> By default, the kubelet creates a mirror pod so that the static Pods are visible in the Kubernetes API. However, if the attacker uses an invalid namespace name when creating the Pod, it will not be visible in the Kubernetes API and can only be discovered by tooling that has access to the affected host(s).

- ワロタ。というか StaticPod って名前空間なし(or 不正な名前空間)で作れるのか？

> Only enable the kubelet static Pod manifest functionality if required by the node.

- こういうことができるのね

> Regularly audit and centrally report all access to directories or web storage locations that host static Pod manifests and kubelet configuration files.
> The

- こういう、監査、監視すべきコンポーネント一覧とかがないと k8s むずい

> Direct access to the kubelet API is not subject to admission control and is not logged by Kubernetes audit logging. An attacker with direct access to this API may be able to bypass controls that detect or prevent certain actions.

- kubelet の API はログにも残らず、攻撃対象になり得るのか。。。
- 一応認証機能も使えるみたい。kubelet を呼び出すのは基本的に kube-api-server なのかな？schedule する時とかに使うのかな？
- etcd は kube-api-server とバックアップソリューション以外は使わないが、乗っ取られるとやばい
- クライアント証明書認証によって管理されているみたい

> Even without elevating their Kubernetes RBAC privileges, an attacker who can modify etcd can retrieve any API object or create new workloads inside the cluster.

- 恐ろしい。。。

> Typically, etcd client certificates that are only used for health checking can also grant full read and write access.

- これも恐ろしい。health check だけでフルアクセスって。。。

- kubelet がアクセスする unix ソケットに対してアクセス権を持つ攻撃者は新しいコンテナの起動や実行中のコンテナとの通信を行うことができる
- node で稼働している他のコンポーネントから kubelet を分離することで、kubelet の攻撃を緩和しよう

## Linux kernel security constraints for Pods and containers

- Pod に SecurityContext を設定し、Linux ユーザーとグループを定義すると、root ユーザーとしてコンテナが実行されないし、コンテナの設定よりも優先されるから 3rd パーティのコンテナとかを使う時にも重宝するらしい

- UID とかを設定することで hostPath や Capability を制限できる
- seccomp はシステムコールを制限することができる
- AppArmor はプロセスのアクセス権を制限する
- SELinux は security labels を使ってセキュリティポリシーを適用する?
- default の seccomp が常に有効になっているらしい

- seccomp をしたら以下のようなリスクはある(確かに)

  > Configurations might break during application updates
  > Attackers can still use allowed syscalls to exploit vulnerabilities
  > Profile management for individual applications becomes challenging at scale

- 推奨されるのは、より強力な制限が欲しければ、sandbox 環境で動くコンテナランタイムとかを選定することらしい
  - ただ、より多くのコンピュートリソースは必要らしい
- SELinux はファイルへのアクセス範囲を制限する Linux カーネルモジュール
- SecurityContext でラベルを設定することで SELinux の有効化ができる
- AppArmor と SELinux はどちらかが OS で有効になっていて、違いがある

  > Configuration: AppArmor uses profiles to define access to resources. SELinux uses policies that apply to specific labels.
  > Policy application: In AppArmor, you define resources using file paths. SELinux uses the index node (inode) of a resource to identify the resource.

- SELinux はラベルを指定して細かいアクセス制限が可能で、AppArmor はファイルパスで荒いアクセス制限をかける
- Kubernetes Security Profiles Operator という簡単に設定を管理してくれるものがあるらしい

> Before configuring kernel-level security capabilities, you should consider implementing network-level isolation.

> Unless necessary, run Linux workloads as non-root by setting specific user and group IDs in your Pod manifest and by specifying runAsNonRoot: true.

- user id とか group id は常に設定したほうが良いのかな？

## Security Checklist

- system:masters は誰も使うべきではない

> The kube-controller-manager is running with --use-service-account-credentials enabled.

    - これはなぜだっけ？
    - マネージドサービス使っているなら常に守られてそうだけど

- system:master は非常手段として使うべき
- Ingress and egress network policies are applied to all workloads in the cluster.
  - 厳しい...
- Default network policies within each namespace, selecting all pods, denying everything, are in place.
  - ここら辺もミスったら通信できない大事故になる気もする
- LoadBalancer Type の Service とか CVE があるレベルで危険みたい

- 機密性の高いワークロードには CPU 制限をすることとあったが、これをすることで Dos とかに対応できるとあり、なるほどなという感じ
- Seccomp とか AppArmor とかは、マネージドサービスのノードだとどうなっているんだろう
- 監査ログを有効化してとあるから、監査ログを有効化にするオプションでもあるのかな？

  - あるみたい

- Pod の配置を気をつけましょうとのこと

  - これはちゃんとやったほうが良さそう
  - ノード分離と、やるのであれば sandbox な Container Runtime を使うのが良いとのこと

- Secret は暗号化しましょう
- サードパーティのストレージに保存されているシークレットを secret として導入しようとのこと
  - これは k8s 弱気なんか？
- コンテナイメージは sha256 ダイジェストによって行い、タグはやめようとのこと
  - タグじゃ悪さされても気づかないってことかな
  - もしくはアドミッションコントロール経由でデジタル署名の検証をしましょうとのことだけどよくわからんかも
  - imagepolicywebhook を使うとダイジェストを使うことを強制できるのかな
- AdmissionControl ってデフォルトで有効になっている多くものがあるみたい
  - あまりよく分かってないから見るのアリかも
  - ResourceQuota とかも AdmissionControl の一つみたい

## Application Security Checklist

- CPU,Memory Limit は設定しようとのことだけど、ここら辺自動的にいい感じにできたらな
- ServiceAccount は default 以外の作成したものを使おうとのこと
- runAsNonRoot は常に true にしようとのこと
- image signature がどのようにするのかがよく分かってないかも

  - なんかツールとかあるのかな？
  - signature ってことは秘密鍵は必要そうだけど、そこら辺の管理はしたくないな

- AdmissionControl とかを組み込めばどれもプラットフォームとして提供できそうな雰囲気
- 逆にこの CheckList をみてプラットフォームを組み込むのはアリだなという感じ

## LimitRanges

- LimitRange で namespace ないの CPU や memory、storage のリソースを制限できる
- namespace にデフォルトの設定もできるみたい
- リソースの設定を超える場合はスケジュールされない

## Resource Quotas

- namespace ごとの集約リソースの消費量を制限する制約、総量で判断するぽい？
- 異なるチームが異なる namepsace を利用している時とか、に使えるっぽい
- ResourceQuota を使うのであれば全ての Pod に requests や limits を設定する必要があるみたい
- 設定しない場合、ResourceQuota には無視されて換算されないみたい
- pvc の数とかも制御できるのか
- Object Count Quota とかもあるみたいで様々なオブジェクトの個数も制御できるのか
- Scope なるものも指定できて、Scope で指定された状態？にあるオブジェクトのみがカウントされるみたい
  - ここまで指定できる組織って日本にあるのか？
  - 指定してそこまで嬉しいことってあるんかな？
  - レベル高すぎる

## Process ID Limits And Reservations

- Pod が利用できる PID の数を制限できるみたい
- こんなものどうやって必要最低限な数を計算するんだろう
- ただ、モチベーションとしては、他の Pod とかに影響を与えないために制限するということらしい
- Pod の spec ではなく kubelet に指定するみたい
- プロセス ID の予約もできるみたい
- pid の数を kubelet の eviction ポリシーとして設定できるみたい
- kubelet の設定ってことはマネージドサービスとかだとそもそもできない、もしくはプロバイダー側が指定してくれている説がある？
- PID の上限に達した時、Pod は障害を起こすとあるけどどういうこと？
- その反応次第で再スケジュールするかしないかを決定するみたい
- ここら辺のハンドリング手法も PID を制限するのであれば必要ってことかな

## Node Resource Managers

- 低遅延高スループットなワークロードを実行するために、k8s は一連のリソースマネージャーを提供しているみたい
- Topology Manager はコンポーネント群を調整することを目的とした kubelet コンポーネント
- CPU マネージャーや Memory マネージャー, Device Manager などもあるみたい
- Fargate 使えばこれらを諦められる...(それが最適かどうかは置いておいて)
- Linux とか CS の知識をたくさん持っていればここら辺の話もわかるようになるのか？

## Kubernetes のスケジューラー

- kube-scheduler は別のスケジュールコンポーネントを代わりに差し込むこともできるようになっているみたい。。
- スケジューラーは Pod に対する割り当て可能な Node を見つけ、それらの割り当て可能な Node にスコアをつけて、その中から最も高いスコアの Node を選択して Pod に割り当てるみたい
- binding っていう処理の中で API サーバーに割り当てリクエストを送るとのこと
- フィルタリングでスケジュール可能な Node を探し、スコアリングで最適な Node を選ぶとのこと

## ノード上への Pod のスケジューリング

- ラベルセレクターを使用してノードの制約をかけるのが推奨
- ノードのラベルを利用する場合は、kubelet が修正できないラベルを選択することで、ノードが侵害されてもそのノードへのスケジュールを防ぐことができる
- nodeSelector は単純にノードをラベルで指定するもので、それより柔軟なのが nodeAffinity というもの
- Pod 間のアフィニティやアンチアフィニティも設定できる
- requiredDuringSchedulingIgnoredDuringExecution は Pod がスケジュールされる前にノードが条件を満たしているかどうかを確認するもの
  - preferredDuringSchedulingIgnoredDuringExecution は条件を満たすノードがない場合に Pod をスケジュールするもの
- IgnoredDuringExecution は Pod がスケジュールされた後に条件が変わっても Pod が削除されないもの
- ここら辺は要件だけ考えて AI が正確にやってくれたら嬉しいな
- preferredDuringSchedulingIgnoredDuringExecution は weight を指定できるっぽい
- addedAffinity を設定すると、Pod に適用させたいデフォルトのスケジューラーを作成できるみたい
  - いちいち pod で preferredDuringSchedulingIgnoredDuringExecution とかを設定せずとも使いまわせるってことかな？

> Pod 間アフィニティとアンチアフィニティはかなりの処理量を必要とするため、大規模クラスターでのスケジューリングが大幅に遅くなる可能性があります そのため、数百台以上のノードから成るクラスターでの使用は推奨されません。

- これは気をつけねば。。。
- Pod 間アフィニティは deployment のセットとかに対して実行するといいケースがあるみたい

## Pod のオーバーヘッド

- Pod のオーバーヘッドはコンテナの要求と制限に加えて Pod のインフラで消費されるリソースを計算するための機能
  - limit,requests ってコンテナにだけ適用されるものだったんだと、ここで知った
- この機能を使うには RuntimeClass が必要見たい
- kube-scheduler は Pod のオーバーヘッドとコンテナ要求の合計を見るとあるので、Pod 全体の消費量ではなく、コンテナの消費量を差し引いたオーバーヘッドのみを設定するって感じか

  - これってどんぐらいあるんだろ？コンテナの消費量に比べて少ないと思っているけど。。
  - あとはコンテナの数とかでどのくらい変わってくるのか？

> Pod のオーバヘッドが利用されているタイミングを特定し、定義されたオーバーヘッドで実行されているワークロードの安定性を観察するため、kube-state-metrics には kube_pod_overhead というメトリクスが用意されています。

- どのようなデータがどのように取得できるのか？そしてそれを観察し続けるのは大事だな〜

## Pod トポロジー分散制約

- Pod が増減する時に、障害性やレイテンシーのことを考えると、node やゾーンに対してうまいこと分散させる必要があるよねという話

```
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  # トポロジー分散制約を設定
  topologySpreadConstraints:
    - maxSkew: <integer>
      minDomains: <integer> # オプション
      topologyKey: <string>
      whenUnsatisfiable: <string>
      labelSelector: <object>
      matchLabelKeys: <list> # オプション; v1.27以降ベータ
      nodeAffinityPolicy: [Honor|Ignore] # オプション; v1.26以降ベータ
      nodeTaintsPolicy: [Honor|Ignore] # オプション; v1.26以降ベータ
  ### 他のPodのフィールドはここにあります
```

- maxSkew は Pod が不均等に分散される程度

> topologyKey はノードラベルのキーです。 このキーと同じ値を持つノードは、同じトポロジー内にあると見なされます。 トポロジー内の各インスタンス(つまり、<key, value>ペア)をドメインと呼びます。 スケジューラーは、各ドメインに均等な数の Pod を配置しようとします。 また、適格ドメインは nodeAffinityPolicy と nodeTaintsPolicy の要件を満たすノードのドメインとして定義します。

- az とかで topologyKey を設定すると、az ごとに Pod を分散させることができるってことかな?
- nodeAffinity とか nodeTaints とかをトポロジーを考慮する際に、考慮するか、無視するかの設定ができるみたい

- 複数制約を適用すると、どちらも満たされない時に pending 状態で止まることもあるみたい

  - whenUnsatisfiable: ScheduleAnyway とかを設定することで、無視してスケジュールすることもできるが、そうなると、設定ミスに気づかないこともありそう(監視して、warn が出てないかなどを見れば良いのか？)

- 暗黙的な落とし穴もあるみたいで、よくわからなかったが、注意必要

  - マネージドなサービスであれば問題なさそうだが、node へのラベルつけ忘れやタイポをすると意図しないことになるとのこと
  - あとは新しい Pod と同じ Ns を持つ Pod のみが一致する候補になるみたい

- クラスターにデフォルトのトポロジー分散制約を設定することができるみたい

  - topologySpreadConstraints に 制約が定義されておらず、Pod が Service や ReplicaSet などに属しているときに適用されるみたい

- クラスターレベルのデフォルト制約を構成しない場合は以下のトポロジー制約を指定したかのように動作するみたい

```
defaultConstraints:
  - maxSkew: 3
    topologyKey: "kubernetes.io/hostname"
    whenUnsatisfiable: ScheduleAnyway
  - maxSkew: 5
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: ScheduleAnyway
```

- デフォルトの Pod 分散制約は無効化することもできる見たい

```
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration

profiles:
  - schedulerName: default-scheduler
    pluginConfig:
      - name: PodTopologySpread
        args:
          defaultConstraints: []
          defaultingType: List
```

- 既知の制限もあるみたい

## Pod のスケジューリング準備

- 絶対スケジュールできない Pod がいつづけるのがよく無さそうなので schedulingGates を指定したり削除したりすることで、スケジューリングを保留にすることができる？
- ただ、新しい schedulingGate を追加できず、人間が schedulegate を設定、削除するのはよくわからん
- Pod をデプロイしたけど、リソース不足でスケジュールできませんでした、だからスケジュール対象から外したいです、ということならわかるけど、作成時にしか指定できないのならこれ使うことあるか？
- pod スケジューリング命令は変更できるものとそうでないものがあるみたいだから注意

## Taint と Toleration

- Taint は Node から Pod を排除するために使用される
- Toleration は Taint に対して Pod が許容できることを指定するが必ずしもその node にスケジュールされるわけではない

> toleration が taint と合致するのは、key と effect が同一であり、さらに下記の条件のいずれかを満たす場合です。

- Pod に指定するとき effect も一致している必要があるのは微妙に違和感

- NoExecute の効果は以下で、Pod がスケジュールされている node に taint が追加された場合、Pod は削除される

> 対応する toleration のない Pod は即座に除外される
> 対応する toleration があり、それに tolerationSeconds が指定されていない Pod は残り続ける
> 対応する toleration があり、それに tolerationSeconds が指定されている Pod は指定された間、残される

## スケジューリングフレームワーク

- スケジューリングフレームワークは Kubernetes のスケジューラーに対してプラグイン可能なアーキテクチャ
- 1 つの Pod をスケジュールしようとする各動作は Scheduling Cycle と Binding Cycle の 2 つのフェーズ
- scheduling framework extension points は、自分たちがフレームワークとか作る上でも参考にできそう
  - ここまでプラグインできる場所があるんか

## 動的リソース割り当て

- 新目の機能
- Pod と Pod 内のコンテナ間でリソースを要求および共有するための API
- GPU 用の機能？
- kubelet が動的リソースの検出を可能にする gPRC サービスを提供しているっぽい

## スケジューラーのパフォーマンスチューニング

- スケジューラーは Binding と呼ばれる処理で API サーバーに対して割り当てが決まったノードの情報を通知する

> スケジューリング性能を改善するため、kube-scheduler は割り当て可能なノードが十分に見つかるとノードの検索を停止できます。大規模クラスターでは、すべてのノードを考慮する単純なアプローチと比較して時間を節約できます。

- こんなことができたのか。。これ EKS とかでもできるのかな？
- ここまで考えるべき大規模の規模感ってどんぐらいだろ

> 閾値を指定しない場合、Kubernetes は 100 ノードのクラスターでは 50%、5000 ノードのクラスターでは 10%になる線形方程式を使用して数値を計算します。自動計算の下限は 5%です。

- 結構これでもいい感じな気もする
- デフォルトでは最低でも 5％のノードに対して評価してくれる
- これって、大規模クラスターでパフォーマンスを上げられる余地って 0〜4%ってことか

> 割り当て可能なノードが 100 以下のクラスターでは、スケジューラの検索を早期に停止するのに十分な割り当て可能なノードがないため、スケジューラはすべてのノードをチェックします。

> 小規模クラスターでは、percentageOfNodesToScore に低い値を設定したとしても、同様の理由で変更による影響は全くないか、ほとんどありません。

> クラスターのノード数が数百以下の場合は、この設定オプションをデフォルト値のままにします。変更してもスケジューラの性能を大幅に改善する可能性はほとんどありません。

- この説明良いな
- 100 ノードってどのくらいなんだろ？あとノードのスペックにもよるしな
- eks だと 1 ノード 110pod が制限らしいから、100 ノードだと 1 万 1 千 pod ぐらいか
- モノリスなシステムだったら余裕で 100 ノードぐらいでいけそうな気もする
- 基本的には 10％未満にしないでくださいとのこと

  - うまく配置されなくなるので

- スケジューラーはラウンドロビン方式でノードを探索しているらしい
  - 案外普通だった

## 拡張リソースのリソースピンバッキング

> 「Bin Packing（ビンパッキング）」とは、たとえば「限られた大きさの箱（bin）に物を効率よく詰める」という問題のことです。by ChatGPT

- pod をできるだけ node に効率よく詰めること？
- weight を設定することで、配置に優先順位をつけることができる?
- shape.utilization で詰め込んでいる node に対してスコアリングできる
- スケジューリングの計算の例もあるのでなんとなくわかる

## Pod の優先度とプリエンプション

- 優先度を設定すると、優先度の高い pod のために優先度の低い pod を追い出すことができる機能っぽい

  > クラスターの全てのユーザーが信用されていない場合、悪意のあるユーザーが可能な範囲で最も高い優先度の Pod を作成することが可能です。これは他の Pod が追い出されたりスケジューリングできない状態を招きます。 管理者は ResourceQuota を使用して、ユーザーが Pod を高い優先度で作成することを防ぐことができます。

- 怖いね〜。パブクラとかを k8s で作るときはこんな感じになるかもって感じなのかな
- priorityClass を作成して、pod で指定するみたい

> PriorityClass オブジェクトは 10 億以下の任意の 32 ビットの整数値を持つことができます。これは、PriorityClass オブジェクトの値の範囲が-2147483648 から 1000000000 までであることを意味します。 それよりも大きな値は通常はプリエンプトや追い出すべきではない重要なシステム用の Pod のために予約されています。

- 予約の仕方賢い気がする。こういう感じで予約とかしていけば良いのかな？

- 以下のようなシンプルな感じみたい

```
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "この優先度クラスはXYZサービスのPodに対してのみ使用すべきです。"
```

> preemptionPolicy: Never と設定された Pod は、スケジューリングのキューにおいて他の優先度の低い Pod よりも優先されますが、他の Pod をプリエンプトすることはありません。 スケジューリングされるのを待つ非プリエンプトの Pod は、リソースが十分に利用可能になるまでスケジューリングキューに残ります。

- 優先度高くしたいが、リソースを追い出すまでもない場合は preemptionPolicy: Never とすると良いみたい
- プリエンプとされても pod には終了までの猶予期間があるため、プリエンプとした時刻と待機状態の Pod がノードにスケジュール可能になるまでの時刻の間に間が開くみたい
- pod の猶予期間を 0 などの小さい値にすると、間が空きにくくなる

> Kubernetes は Pod をプリエンプトする際に PDB に対応しますが、PDB はベストエフォートで考慮します。スケジューラーはプリエンプトさせたとしても PDB に違反しない Pod を探します。そのような Pod が見つからない場合でもプリエンプションは実行され、PDB に反しますが優先度の低い Pod が追い出されます。

- これ結構罠なのでは？ただ、優先度低いのに PDB で最小数を決めておくってのは少しオペレーション的に違和感はある
- 待機状態の Pod よりも優先度の低い Pod をノードから全て追い出したら、待機状態の Pod をノードへスケジュールできるかの条件が真の時のみプリエンプションの対象になる
- なので、Pod 間のアフィニティを持つ場合は Pod 間のアフィニティはそれらの優先度の低い pod がなければ満たされない
- なので、優先度が同一か高い pod に対してのみ Pod 間のアフィニティを設定することが重要

## ノードの圧迫による退避

- kubelet はリソース監視をしており、リソースの 1 つ以上が特定の消費レベルに達すると kubelet はリソースの枯渇を防ぐためにノード上の 1 つ以上の pod を事前に停止してリソースを回収する
- kubelet はノードのリソース枯渇による退避中に kubelet は選択された Pod のフェーズを Failed に設定し、Pod を終了する

  - 最近 CPU が爆発することがあったけど Failed にはならなかったような
  - CPU は見てない？(そんなことはないと思うけど)

- PDB や terminationGracePeriodSeconds などを気にせずに削除するみたい
- static Pod に対しても退避させることがあるみたい

> kubelet は、エンドユーザーの Pod を終了する前にノードレベルのリソースを回収しようとします。 例えば、ディスクリソースが枯渇している場合は未使用のコンテナイメージを削除します。

- Pod が退避されるとそれを管理している Deployment などは新しい Pod を作成するみたい
  - 使い回しではないということ
- kubelet は退避を決定するために退避シグナルや退避閾値、監視感覚などのパラメータを使用する
- 退避シグナルはある時点での特定リソースの状態を表すもので、シグナルと退避閾値を比較して退避を決定するみたい
  - 退避シグナルには memory は nodefs,imagefs,containerfs,pid などが

## API を起点とした退避

- Eviction API を使用して退避オブジェクトを作成し、Pod の正常終了を起動させるプロセス
- kubectl drain にっても可能
- PDB と terminationGracePeriodSeconds を考慮して、Pod を削除するみたい
- うまくいけば 200 OK だが、PDB の設定によって退去が許可されていないことがわかると 429 を返すらしい
  - 若干 429 ではない気がするけど、PDB の調整が時間経過で良くなる可能性があるからみたい
- 500 も返すらしく、複数の PDB が同じ Pod を参照しているなどの、設定に誤りがあり、退去が許可されないことを示すらしい

  - これも 500？
  - invalid parameter とか 400 番台であったような

- 200 を返したら、以下の流れで Pod が削除される

  1. 削除タイムスタンプをそ更新して、Pod が終了したとみなす

  - このとき Pod は設定された猶予期間が儲けられる

  2. kubelet が Pod のシャットダウンを開始する
  3. 2 の間にコントロールプレーンは Endpoint オブジェクトから Pod を削除する
  4. Pod の猶予期間が終了すると kubelet はローカル Pod を強制的に終了する
  5. kubelet は API サーバーに Pod リソースを削除するように支持する
  6. API サーバーは Pod リソースを削除 5. kubelet は API サーバーに Pod リソースを削除するように支持する

- アプリケーションが壊れた状態になると Eviction API が聞かなくなることもあるらしい
- アプリケーションの調査や Eviction API の代わりにコントロールプレーンから直接 Pod を削除する必要がある
  - こういうよくわからん状態に陥ることがあるのが怖い

## NodeShutdowns

- kubelet が os のシャットダウン通知を受け取り、Pod を段階的に終了させる機能
  - 電源供給がなくなっても稼働するっていうのは電源がなくても稼働するってこと？そんなことある？
- systemd が SIGTERM を kubelet に送ることで動作開始
- kubelet は非クリティカル Pod,クリティカル Pod の順で Pod を終了させる

- クリティカル Pod は、以下の条件をすべて満たすもの：
  - Static Pod かつ kube-system namespace
  - priorityClassName が以下のいずれか：
  - system-node-critical
  - system-cluster-critical

## Node AutoScaling

- Node Provisioning: スケジュールできない Pod が存在する場合、新しいノードを自動的に追加
- Node Consolidation: リソースの利用率が低いノードを削除し、クラスターの効率を向上させる
- Cluster Autoscaler とか Karpenter などがある

## Cluster Networking

- k8s のネットワーク周りの基本の話

## Admission Webhook Good Practices

- Webhook のベスプラみたいなものが多く描かれている
- もし自分で作成する必要が出てきたら見直しても良いかも

## Logging Architecture

- Kubernetes v1.32 では、アルファ機能として PodLogsQuerySplitStreams フィーチャーゲートが導入され、コンテナの標準出力と標準エラー出力を個別に取得できるようになった

- Kubernetes は、コンテナランタイムを通じて、各コンテナの stdout および stderr をログファイルとして保存
- これらのログは、CRI（Container Runtime Interface）ログ形式で /var/log/pods ディレクトリ内に保存される
- log rotation の設定も可能

## Compatibility Version For Kubernetes Control Plane Components

- --emulated-version フラグを使用すると、コントロールプレーンコンポーネントが指定した過去の Kubernetes バージョンの動作をエミュレート（模倣）することができる

- 利用シナリオとしては
  - 段階的なアップグレード
  - 後方互換性の維持
  - テストと検証
- コンポーネント単位でできそうなので、あるリソースだけバージョンアップせずに調整できる感じ

## Metrics for Kubernetes System Components

- Kubernetes の各システムコンポーネント（例：kube-apiserver、kube-scheduler、kube-controller-manager、kubelet、kube-proxy）は、内部状態やパフォーマンスを示すメトリクスを Prometheus 形式で /metrics エンドポイントから公開している

- メトリクスの公開を k8s レベルでやっているとは思っていなかった

## Metrics for Kubernetes Object States

- kube-state-metrics は、Kubernetes クラスター内のオブジェクトの状態に関するメトリクスを生成し、HTTP エンドポイントを通じて公開するアドオンエージェント

- このコンポーネントは、Kubernetes API サーバーと接続し、各オブジェクトの状態（例：ラベル、アノテーション、起動・終了時刻、ステータス、フェーズなど）に基づいたメトリクスを生成する

- このコンポーネントを使用するには、Prometheus などのメトリクス収集ツールと連携する必要がある

## System Logs

- klog は kubernets のロギングライブラリ
  - 標準エラーに出力されるみたい
- ContextualLogger を使用して、ログのコンテキストを追加することができる

- コンテナ内で実行されるコンポーネント（例：kube-scheduler、kube-proxy）：​/var/log ディレクトリ内の .log ファイルにログを出力

- コンテナ外で実行されるコンポーネント（例：kubelet、コンテナランタイム）：

  - systemd 使用時：journald にログを出力します。
  - 非 systemd 環境：/var/log ディレクトリ内の .log ファイルにログを出力します。

- Kubernetes v1.30 でベータ版として導入されたログクエリ機能を使用すると、ノード上のサービスのログを取得可能

## Traces For Kubernetes System Components

> Kubernetes components have built-in gRPC exporters for OTLP to export traces, either with an OpenTelemetry Collector, or without an OpenTelemetry Collector.

- 全然知らなかった。。

- TracingConfiguration を config として設定することでトレースを収集できるっぽい？
  - これは kube-apiserver の話
- KubeletConfiguration をやると kubelet の設定ができるっぽい
- これって任意のバックエンドに送信できるってことだよな？

## Proxies in Kubernetes

- kubectl proxy とか kube proxy とか
- 性質の違う proxy の紹介

## API Priority and Fairness

- APF って略すっぽい
- API サーバーへの負荷上限を設定する最近の設定
- きめ細かい方法でリクエストを分類し、分離する
- バーストの場合にリクエストが拒否されないように、キューを導入して、あるリソースのリクエストが他のリソースの邪魔にならないようにする
- コマンドで設定できるらしいけど、デフォルトで使えるっぽい
- 優先度とか公平性を考慮したものらしい
- PriorityLevelConfiguration で、リクエストの優先度を定義できるみたい
- FlowSchema で、どのリクエストをどの PriorityLevelConfiguration にマッピングするかを定義できるみたい
- Seats によってリクエストの重みづけも設定できるみたい
- Exempt(免除)されるリクエストもある

## Installing Addons

- たくさんのプロダクトが載っている感じ

## Coordinated Leader Election

- めちゃ新しい機能でまだ alpha
- 結局何が嬉しいのか、何ができるのかがよくわからなかった
- 新しいリーダ選出のアルゴリズムって感じ？

## Kubernetes を拡張する

- ホスティングされた Kubernetes サービスやマネージドな Kubernetes では、フラグと設定ファイルが常に変更できるとは限りません。変更可能な場合でも、通常はクラスターの管理者のみが変更できます。また、それらは将来の Kubernetes バージョンで変更される可能性があり、設定変更にはプロセスの再起動が必要になるかもしれません。これらの理由により、この方法は他の選択肢が無いときにのみ利用するべきです。
- 変更可能な場合でも、通常はクラスターの管理者のみが変更できます。また、それらは将来の Kubernetes バージョンで変更される可能性があり、設定変更にはプロセスの再起動が必要になるかもしれません。これらの理由により、この方法は他の選択肢が無いときにのみ利用するべきです。

## カスタムリソース

- カスタムリソースそれ自身は、単純に構造化データを格納、取り出す機能を提供します。カスタムリソースを カスタムコントローラー と組み合わせることで、カスタムリソースは真の 宣言的 API を提供します。
- カスタムリソースをクラスターに追加するべきか？ が有用
- アグリゲート API は、プロキシとして機能するプライマリ API サーバーの背後にある、下位の APIServer です。このような配置は API アグリゲーション(AA)と呼ばれています。ユーザーにとっては、単に API サーバーが拡張されているように見えます。
- CRD では、API サーバーの追加なしに、ユーザーが新しい種類のリソースを作成できます。CRD を使うには、API アグリゲーションを理解する必要はありません。
- CRD と AA 比較表も有用 -カスタムリソースは、ConfigMap と同じ方法でストレージの容量を消費します。

## アグリゲーションレイヤーを使った Kubernetes API の拡張

- アグリゲーションレイヤーを使用すると、Kubernetes のコア API で提供されている機能を超えて、追加の API で Kubernetes を拡張できます。追加の API は、service-catalog のような既製のソリューション、または自分で開発した API のいずれかです。
- 拡張 API サーバーは、kube-apiserver との間の低遅延ネットワーキングが必要です。

## オペレーターパターン

- 例
  - 必要に応じてアプリケーションをデプロイする
  - アプリケーションの状態のバックアップを取得、リストアする
  - アプリケーションコードの更新と同時に、例えばデータベーススキーマ、追加の設定修正など必要な変更の対応を行う
  - Kubernetes API をサポートしていないアプリケーションに、サービスを公開してそれらを発見する
  - クラスターの回復力をテストするために、全て、または一部分の障害をシミュレートする
  - 内部のリーダー選出プロセス無しに、分散アプリケーションのリーダーを選択する

## コンピュート、ストレージ、ネットワーキングの拡張機能

- ネットワーキングの文脈におけるコンテナランタイムは、ノード上のデーモンであり、kubelet 向けの CRI サービスを提供するように設定されています。 特に、コンテナランタイムは、Kubernetes ネットワークモデルを実装するために必要な CNI プラグインを読み込むように設定する必要があります。
- Kubernetes 1.24 以前は、CNI プラグインは cni-bin-dir や network-plugin といったコマンドラインパラメーターを使用して kubelet によって管理することもできました。 これらのコマンドラインパラメーターは Kubernetes 1.24 で削除され、CNI の管理は kubelet の範囲外となりました。
- Kubernetes ネットワークモデルを実装するためにノードにインストールされた CNI プラグインに加えて、Kubernetes はコンテナランタイムにループバックインターフェース lo を提供することも要求します。 これは各サンドボックス(Pod サンドボックス、VM サンドボックスなど)に使用されます。
- CNI ネットワーキングプラグインは hostPort をサポートしています。 CNI プラグインチームが提供する公式の portmap プラグインを使用するか、ポートマッピング(portMapping)機能を持つ独自のプラグインを使用できます。

## Device Plugin

- Kubernetes Device Plugin とは？
- Kubernetes に GPU、FPGA、NIC などの 特殊なハードウェア を使わせたい場合、Device Plugin を使って ノードの拡張ができます。
- Kubernetes 本体のコードを変更せずに、 任意のハードウェアデバイスを Pod に割り当てられるようにする。
