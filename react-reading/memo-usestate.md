- packages/react/index.js で useState が re export されている感じ

```js
export function useState<S>(
  initialState: (() => S) | S
): [S, Dispatch<BasicStateAction<S>>] {
  const dispatcher = resolveDispatcher();
  return dispatcher.useState(initialState);
}

// Aを受け取って何も返さない関数
type Dispatch<A> = (A) => void;

// 更新関数
type BasicStateAction<S> = ((S) => S) | S;
```

react -> ReactHooks -> ReactSharedInternals -> react

```js
function resolveDispatcher() {
  const dispatcher = ReactSharedInternals.H;
  return ((dispatcher: any): Dispatcher);
}
```

```js
export type Dispatcher = {
  use: <T>(Usable<T>) => T,
  readContext<T>(context: ReactContext<T>): T,
  useState<S>(initialState: (() => S) | S): [S, Dispatch<BasicStateAction<S>>],
  useReducer<S, I, A>(
    reducer: (S, A) => S,
    initialArg: I,
    init?: (I) => S
  ): [S, Dispatch<A>],
  useContext<T>(context: ReactContext<T>): T,
  useRef<T>(initialValue: T): { current: T },
  useEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null
  ): void,
  // TODO: Non-nullable once `enableUseEffectEventHook` is on everywhere.
  useEffectEvent?: <Args, F: (...Array<Args>) => mixed>(callback: F) => F,
  useInsertionEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null
  ): void,
  useLayoutEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null
  ): void,
  useCallback<T>(callback: T, deps: Array<mixed> | void | null): T,
  useMemo<T>(nextCreate: () => T, deps: Array<mixed> | void | null): T,
  useImperativeHandle<T>(
    ref: { current: T | null } | ((inst: T | null) => mixed) | null | void,
    create: () => T,
    deps: Array<mixed> | void | null
  ): void,
  useDebugValue<T>(value: T, formatterFn: ?(value: T) => mixed): void,
  useDeferredValue<T>(value: T, initialValue?: T): T,
  useTransition(): [
    boolean,
    (callback: () => void, options?: StartTransitionOptions) => void
  ],
  useSyncExternalStore<T>(
    subscribe: (() => void) => () => void,
    getSnapshot: () => T,
    getServerSnapshot?: () => T
  ): T,
  useId(): string,
  useCacheRefresh: () => <T>(?() => T, ?T) => void,
  useMemoCache: (size: number) => Array<any>,
  useHostTransitionStatus: () => TransitionStatus,
  useOptimistic: <S, A>(
    passthrough: S,
    reducer: ?(S, A) => S
  ) => [S, (A) => void],
  useFormState: <S, P>(
    action: (Awaited<S>, P) => S,
    initialState: Awaited<S>,
    permalink?: string
  ) => [Awaited<S>, (P) => void, boolean],
  useActionState: <S, P>(
    action: (Awaited<S>, P) => S,
    initialState: Awaited<S>,
    permalink?: string
  ) => [Awaited<S>, (P) => void, boolean],
};
```

```js
const ReactSharedInternals =
  React.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;
```

```
// React.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;の実態は以下
const ReactSharedInternals: SharedStateClient = ({
  H: null,
  A: null,
  T: null,
  S: null,
}: any);
// おそらくSharedStateClientを初期化している
```

```
export type SharedStateClient = {
  H: null | Dispatcher, // ReactCurrentDispatcher for Hooks
  A: null | AsyncDispatcher, // ReactCurrentCache for Cache
  T: null | Transition, // ReactCurrentBatchConfig for Transitions
  S: null | onStartTransitionFinish,
  G: null | onStartGestureTransitionFinish,

  // DEV-only

  // ReactCurrentActQueue
  actQueue: null | Array<RendererTask>,

  // When zero this means we're outside an async startTransition.
  asyncTransitions: number,

  // Used to reproduce behavior of `batchedUpdates` in legacy mode.
  isBatchingLegacy: boolean,
  didScheduleLegacyUpdate: boolean,

  // Tracks whether something called `use` during the current batch of work.
  // Determines whether we should yield to microtasks to unwrap already resolved
  // promises without suspending.
  didUsePromise: boolean,

  // Track first uncaught error within this act
  thrownErrors: Array<mixed>,

  // ReactDebugCurrentFrame
  getCurrentStack: null | (() => string),

  // ReactOwnerStackReset
  recentlyCreatedOwnerStacks: 0,
};
```

```
function updateForwardRef(
  current: Fiber | null,
  workInProgress: Fiber,
  Component: any,
  nextProps: any,
  renderLanes: Lanes,
) {
  // TODO: current can be non-null here even if the component
  // hasn't yet mounted. This happens after the first render suspends.
  // We'll need to figure out if this is fine or can cause issues.
  const render = Component.render;
  const ref = workInProgress.ref;

  let propsWithoutRef;
  if ('ref' in nextProps) {
    // `ref` is just a prop now, but `forwardRef` expects it to not appear in
    // the props object. This used to happen in the JSX runtime, but now we do
    // it here.
    propsWithoutRef = ({}: {[string]: any});
    for (const key in nextProps) {
      // Since `ref` should only appear in props via the JSX transform, we can
      // assume that this is a plain object. So we don't need a
      // hasOwnProperty check.
      if (key !== 'ref') {
        propsWithoutRef[key] = nextProps[key];
      }
    }
  } else {
    propsWithoutRef = nextProps;
  }

  // The rest is a fork of updateFunctionComponent
  prepareToReadContext(workInProgress, renderLanes);
  if (enableSchedulingProfiler) {
    markComponentRenderStarted(workInProgress);
  }

  const nextChildren = renderWithHooks(
    current,
    workInProgress,
    render,
    propsWithoutRef,
    ref,
    renderLanes,
  );
  const hasId = checkDidRenderIdHook();

  if (enableSchedulingProfiler) {
    markComponentRenderStopped();
  }

  if (current !== null && !didReceiveUpdate) {
    bailoutHooks(current, workInProgress, renderLanes);
    return bailoutOnAlreadyFinishedWork(current, workInProgress, renderLanes);
  }

  if (getIsHydrating() && hasId) {
    pushMaterializedTreeId(workInProgress);
  }

  // React DevTools reads this flag.
  workInProgress.flags |= PerformedWork;
  reconcileChildren(current, workInProgress, nextChildren, renderLanes);
  return workInProgress.child;
}
```

```
function beginWork(
  current: Fiber | null,
  workInProgress: Fiber,
  renderLanes: Lanes,
): Fiber | null {
  if (__DEV__) {
    if (workInProgress._debugNeedsRemount && current !== null) {
      // This will restart the begin phase with a new fiber.
      const copiedFiber = createFiberFromTypeAndProps(
        workInProgress.type,
        workInProgress.key,
        workInProgress.pendingProps,
        workInProgress._debugOwner || null,
        workInProgress.mode,
        workInProgress.lanes,
      );
      copiedFiber._debugStack = workInProgress._debugStack;
      copiedFiber._debugTask = workInProgress._debugTask;
      return remountFiber(current, workInProgress, copiedFiber);
    }
  }

  if (current !== null) {
    const oldProps = current.memoizedProps;
    const newProps = workInProgress.pendingProps;

    if (
      oldProps !== newProps ||
      hasLegacyContextChanged() ||
      // Force a re-render if the implementation changed due to hot reload:
      (__DEV__ ? workInProgress.type !== current.type : false)
    ) {
      // If props or context changed, mark the fiber as having performed work.
      // This may be unset if the props are determined to be equal later (memo).
      didReceiveUpdate = true;
    } else {
      // Neither props nor legacy context changes. Check if there's a pending
      // update or context change.
      const hasScheduledUpdateOrContext = checkScheduledUpdateOrContext(
        current,
        renderLanes,
      );
      if (
        !hasScheduledUpdateOrContext &&
        // If this is the second pass of an error or suspense boundary, there
        // may not be work scheduled on `current`, so we check for this flag.
        (workInProgress.flags & DidCapture) === NoFlags
      ) {
        // No pending updates or context. Bail out now.
        didReceiveUpdate = false;
        return attemptEarlyBailoutIfNoScheduledUpdate(
          current,
          workInProgress,
          renderLanes,
        );
      }
      if ((current.flags & ForceUpdateForLegacySuspense) !== NoFlags) {
        // This is a special case that only exists for legacy mode.
        // See https://github.com/facebook/react/pull/19216.
        didReceiveUpdate = true;
      } else {
        // An update was scheduled on this fiber, but there are no new props
        // nor legacy context. Set this to false. If an update queue or context
        // consumer produces a changed value, it will set this to true. Otherwise,
        // the component will assume the children have not changed and bail out.
        didReceiveUpdate = false;
      }
    }
  } else {
    didReceiveUpdate = false;

    if (getIsHydrating() && isForkedChild(workInProgress)) {
      // Check if this child belongs to a list of muliple children in
      // its parent.
      //
      // In a true multi-threaded implementation, we would render children on
      // parallel threads. This would represent the beginning of a new render
      // thread for this subtree.
      //
      // We only use this for id generation during hydration, which is why the
      // logic is located in this special branch.
      const slotIndex = workInProgress.index;
      const numberOfForks = getForksAtLevel(workInProgress);
      pushTreeId(workInProgress, numberOfForks, slotIndex);
    }
  }

  // Before entering the begin phase, clear pending update priority.
  // TODO: This assumes that we're about to evaluate the component and process
  // the update queue. However, there's an exception: SimpleMemoComponent
  // sometimes bails out later in the begin phase. This indicates that we should
  // move this assignment out of the common path and into each branch.
  workInProgress.lanes = NoLanes;

  switch (workInProgress.tag) {
    case LazyComponent: {
      const elementType = workInProgress.elementType;
      return mountLazyComponent(
        current,
        workInProgress,
        elementType,
        renderLanes,
      );
    }
    case FunctionComponent: {
      const Component = workInProgress.type;
      return updateFunctionComponent(
        current,
        workInProgress,
        Component,
        workInProgress.pendingProps,
        renderLanes,
      );
    }
    case ClassComponent: {
      const Component = workInProgress.type;
      const unresolvedProps = workInProgress.pendingProps;
      const resolvedProps = resolveClassComponentProps(
        Component,
        unresolvedProps,
      );
      return updateClassComponent(
        current,
        workInProgress,
        Component,
        resolvedProps,
        renderLanes,
      );
    }
    case HostRoot:
      return updateHostRoot(current, workInProgress, renderLanes);
    case HostHoistable:
      if (supportsResources) {
        return updateHostHoistable(current, workInProgress, renderLanes);
      }
    // Fall through
    case HostSingleton:
      if (supportsSingletons) {
        return updateHostSingleton(current, workInProgress, renderLanes);
      }
    // Fall through
    case HostComponent:
      return updateHostComponent(current, workInProgress, renderLanes);
    case HostText:
      return updateHostText(current, workInProgress);
    case SuspenseComponent:
      return updateSuspenseComponent(current, workInProgress, renderLanes);
    case HostPortal:
      return updatePortalComponent(current, workInProgress, renderLanes);
    case ForwardRef: {
      return updateForwardRef(
        current,
        workInProgress,
        workInProgress.type,
        workInProgress.pendingProps,
        renderLanes,
      );
    }
    case Fragment:
      return updateFragment(current, workInProgress, renderLanes);
    case Mode:
      return updateMode(current, workInProgress, renderLanes);
    case Profiler:
      return updateProfiler(current, workInProgress, renderLanes);
    case ContextProvider:
      return updateContextProvider(current, workInProgress, renderLanes);
    case ContextConsumer:
      return updateContextConsumer(current, workInProgress, renderLanes);
    case MemoComponent: {
      return updateMemoComponent(
        current,
        workInProgress,
        workInProgress.type,
        workInProgress.pendingProps,
        renderLanes,
      );
    }
    case SimpleMemoComponent: {
      return updateSimpleMemoComponent(
        current,
        workInProgress,
        workInProgress.type,
        workInProgress.pendingProps,
        renderLanes,
      );
    }
    case IncompleteClassComponent: {
      if (disableLegacyMode) {
        break;
      }
      const Component = workInProgress.type;
      const unresolvedProps = workInProgress.pendingProps;
      const resolvedProps = resolveClassComponentProps(
        Component,
        unresolvedProps,
      );
      return mountIncompleteClassComponent(
        current,
        workInProgress,
        Component,
        resolvedProps,
        renderLanes,
      );
    }
    case IncompleteFunctionComponent: {
      if (disableLegacyMode) {
        break;
      }
      const Component = workInProgress.type;
      const unresolvedProps = workInProgress.pendingProps;
      const resolvedProps = resolveClassComponentProps(
        Component,
        unresolvedProps,
      );
      return mountIncompleteFunctionComponent(
        current,
        workInProgress,
        Component,
        resolvedProps,
        renderLanes,
      );
    }
    case SuspenseListComponent: {
      return updateSuspenseListComponent(current, workInProgress, renderLanes);
    }
    case ScopeComponent: {
      if (enableScopeAPI) {
        return updateScopeComponent(current, workInProgress, renderLanes);
      }
      break;
    }
    case ActivityComponent: {
      return updateActivityComponent(current, workInProgress, renderLanes);
    }
    case OffscreenComponent: {
      return updateOffscreenComponent(
        current,
        workInProgress,
        renderLanes,
        workInProgress.pendingProps,
      );
    }
    case LegacyHiddenComponent: {
      if (enableLegacyHidden) {
        return updateLegacyHiddenComponent(
          current,
          workInProgress,
          renderLanes,
        );
      }
      break;
    }
    case CacheComponent: {
      return updateCacheComponent(current, workInProgress, renderLanes);
    }
    case TracingMarkerComponent: {
      if (enableTransitionTracing) {
        return updateTracingMarkerComponent(
          current,
          workInProgress,
          renderLanes,
        );
      }
      break;
    }
    case ViewTransitionComponent: {
      if (enableViewTransition) {
        return updateViewTransition(current, workInProgress, renderLanes);
      }
      break;
    }
    case Throw: {
      // This represents a Component that threw in the reconciliation phase.
      // So we'll rethrow here. This might be a Thenable.
      throw workInProgress.pendingProps;
    }
  }

  throw new Error(
    `Unknown unit of work tag (${workInProgress.tag}). This error is likely caused by a bug in ` +
      'React. Please file an issue.',
  );
}

export {beginWork};
```

次はこの呼び出し元を見つける

---

- beginWork は Fiber 型を返す

```
// by CloudCode
  一般的に、Fiberは以下のことをしています：

  1. 仮想DOM要素の表現 - 各React要素（コンポーネント、DOM要素）をFiberオブジェクトとして表現
  2. 作業単位 - Reactが処理する最小単位として機能
  3. 状態管理 - コンポーネントの状態、props、副作用などを追跡
  4. 優先度制御 - どの更新を先に処理するかを決定

  どの具体的な部分について知りたいですか？例えば：
  - Fiberノードの構造
  - beginWork/completeWorkの処理
  - reconciliation（差分検出）の仕組み
  - 優先度とレーンの概念

  簡単に言うと

  Fiberは「作業単位」で、Reactが各コンポーネントに対して何をすべきかを追跡する仕組みです。double
  buffering（alternateフィールド）で効率的な更新を実現し、親子関係（return/child/sibling）でツリー構造を表現しています。

```

```js
// A Fiber is work on a Component that needs to be done or was done. There can
// be more than one per component.
export type Fiber = {
  // These first fields are conceptually members of an Instance. This used to
  // be split into a separate type and intersected with the other Fiber fields,
  // but until Flow fixes its intersection bugs, we've merged them into a
  // single type.

  // An Instance is shared between all versions of a component. We can easily
  // break this out into a separate object to avoid copying so much to the
  // alternate versions of the tree. We put this on a single object for now to
  // minimize the number of objects created during the initial render.

  // Tag identifying the type of fiber.
  tag: WorkTag,

  // Unique identifier of this child.
  key: null | string,

  // The value of element.type which is used to preserve the identity during
  // reconciliation of this child.
  elementType: any,

  // The resolved function/class/ associated with this fiber.
  type: any,

  // The local state associated with this fiber.
  stateNode: any,

  // Conceptual aliases
  // parent : Instance -> return The parent happens to be the same as the
  // return fiber since we've merged the fiber and instance.

  // Remaining fields belong to Fiber

  // The Fiber to return to after finishing processing this one.
  // This is effectively the parent, but there can be multiple parents (two)
  // so this is only the parent of the thing we're currently processing.
  // It is conceptually the same as the return address of a stack frame.
  return: Fiber | null,

  // Singly Linked List Tree Structure.
  child: Fiber | null,
  sibling: Fiber | null,
  index: number,

  // The ref last used to attach this node.
  // I'll avoid adding an owner field for prod and model that as functions.
  ref:
    | null
    | (((handle: mixed) => void) & { _stringRef: ?string, ... })
    | RefObject,

  refCleanup: null | (() => void),

  // Input is the data coming into process this fiber. Arguments. Props.
  pendingProps: any, // This type will be more specific once we overload the tag.
  memoizedProps: any, // The props used to create the output.

  // A queue of state updates and callbacks.
  updateQueue: mixed,

  // The state used to create the output
  memoizedState: any,

  // Dependencies (contexts, events) for this fiber, if it has any
  dependencies: Dependencies | null,

  // Bitfield that describes properties about the fiber and its subtree. E.g.
  // the ConcurrentMode flag indicates whether the subtree should be async-by-
  // default. When a fiber is created, it inherits the mode of its
  // parent. Additional flags can be set at creation time, but after that the
  // value should remain unchanged throughout the fiber's lifetime, particularly
  // before its child fibers are created.
  mode: TypeOfMode,

  // Effect
  flags: Flags,
  subtreeFlags: Flags,
  deletions: Array<Fiber> | null,

  lanes: Lanes,
  childLanes: Lanes,

  // This is a pooled version of a Fiber. Every fiber that gets updated will
  // eventually have a pair. There are cases when we can clean up pairs to save
  // memory if we need to.
  alternate: Fiber | null,

  // Time spent rendering this Fiber and its descendants for the current update.
  // This tells us how well the tree makes use of sCU for memoization.
  // It is reset to 0 each time we render and only updated when we don't bailout.
  // This field is only set when the enableProfilerTimer flag is enabled.
  actualDuration?: number,

  // If the Fiber is currently active in the "render" phase,
  // This marks the time at which the work began.
  // This field is only set when the enableProfilerTimer flag is enabled.
  actualStartTime?: number,

  // Duration of the most recent render time for this Fiber.
  // This value is not updated when we bailout for memoization purposes.
  // This field is only set when the enableProfilerTimer flag is enabled.
  selfBaseDuration?: number,

  // Sum of base times for all descendants of this Fiber.
  // This value bubbles up during the "complete" phase.
  // This field is only set when the enableProfilerTimer flag is enabled.
  treeBaseDuration?: number,

  // Conceptual aliases
  // workInProgress : Fiber ->  alternate The alternate used for reuse happens
  // to be the same as work in progress.
  // __DEV__ only

  _debugInfo?: ReactDebugInfo | null,
  _debugOwner?: ReactComponentInfo | Fiber | null,
  _debugStack?: Error | null,
  _debugTask?: ConsoleTask | null,
  _debugNeedsRemount?: boolean,

  // Used to verify that the order of hooks does not change between renders.
  _debugHookTypes?: Array<HookType> | null,
};
```

- ReactFiberWorkLoop.js が呼び出している

```js
// Cloud Code曰く、最初の子供をnextとして返すらしい
function performUnitOfWork(unitOfWork: Fiber): void {
  // The current, flushed, state of this fiber is the alternate. Ideally
  // nothing should rely on this, but relying on it here means that we don't
  // need an additional field on the work in progress.
  const current = unitOfWork.alternate;

  let next;
  if (enableProfilerTimer && (unitOfWork.mode & ProfileMode) !== NoMode) {
    startProfilerTimer(unitOfWork);
    next = beginWork(current, unitOfWork, entangledRenderLanes);
    stopProfilerTimerIfRunningAndRecordDuration(unitOfWork);
  } else {
    next = beginWork(current, unitOfWork, entangledRenderLanes);
  }

  unitOfWork.memoizedProps = unitOfWork.pendingProps;
  if (next === null) {
    // If this doesn't spawn new work, complete the current work.
    completeUnitOfWork(unitOfWork);
  } else {
    workInProgress = next;
  }
}
```

```js
function completeUnitOfWork(unitOfWork: Fiber): void {
  // Attempt to complete the current unit of work, then move to the next
  // sibling. If there are no more siblings, return to the parent fiber.
  let completedWork: Fiber = unitOfWork;
  do {
    // export const Incomplete = /*                   */ 0b0000000000000001000000000000000;
    // suspend機能かも。非同期処理に関係しているかも。
    if ((completedWork.flags & Incomplete) !== NoFlags) {
      // This fiber did not complete, because one of its children did not
      // complete. Switch to unwinding the stack instead of completing it.
      //
      // The reason "unwind" and "complete" is interleaved is because when
      // something suspends, we continue rendering the siblings even though
      // they will be replaced by a fallback.
      const skipSiblings = workInProgressRootDidSkipSuspendedSiblings;
      unwindUnitOfWork(completedWork, skipSiblings);
      return;
    }

    // The current, flushed, state of this fiber is the alternate. Ideally
    // nothing should rely on this, but relying on it here means that we don't
    // need an additional field on the work in progress.
    const current = completedWork.alternate;
    const returnFiber = completedWork.return;

    let next;
    startProfilerTimer(completedWork);
    next = completeWork(current, completedWork, entangledRenderLanes);
    if (enableProfilerTimer && (completedWork.mode & ProfileMode) !== NoMode) {
      // Update render duration assuming we didn't error.
      stopProfilerTimerIfRunningAndRecordIncompleteDuration(completedWork);
    }
    if (next !== null) {
      // Completing this fiber spawned new work. Work on that next.
      workInProgress = next;
      return;
    }

    const siblingFiber = completedWork.sibling;
    if (siblingFiber !== null) {
      // If there is more work to do in this returnFiber, do that next.
      workInProgress = siblingFiber;
      return;
    }
    // Otherwise, return to the parent
    // $FlowFixMe[incompatible-type] we bail out when we get a null
    completedWork = returnFiber;
    // Update the next thing we're working on in case something throws.
    workInProgress = completedWork;
  } while (completedWork !== null);

  // We've reached the root.
  if (workInProgressRootExitStatus === RootInProgress) {
    workInProgressRootExitStatus = RootCompleted;
  }
}
```

```
⏺ 正解です！beginWork は 最初の子供（first child）だけ を返します。配列ではありません。

  兄弟ノードの仕組み

  Fiberの構造:
  type Fiber = {
    child: Fiber | null,    // 最初の子供
    sibling: Fiber | null,  // 次の兄弟
    return: Fiber | null,   // 親
  }

  具体例

  <div>
    <span>A</span>
    <span>B</span>
    <span>C</span>
  </div>

  Fiberツリーの構造:
  div Fiber
     ↓ child
  span(A) → span(B) → span(C) → null
     ↑        ↑        ↑
   return   return   return

  beginWorkの動作

  1. div の beginWork → span(A) のFiberを返す（最初の子のみ）
  2. span(A) 処理完了後、work loopが span(A).sibling で span(B) に移動
  3. span(B) 処理完了後、work loopが span(B).sibling で span(C) に移動

  兄弟の作成タイミング

  reconcileChildren() 内で全ての兄弟が一度に作成され、sibling ポインタでリンクされます：

  // reconcileChildren内でこんな感じで兄弟を作成
  child1.sibling = child2;
  child2.sibling = child3;
  child3.sibling = null;

  要するに：beginWork は最初の子だけ返し、兄弟はlinked listで管理され、work loopが順番に処理していきます。
```

- performUnitOfWork が beginWork を呼び出しており、performUnittOfWork は以下から呼び出されている

```js
// これ見れば大体掴めそう
function workLoopSync() {
  // Perform work without checking if we need to yield between fiber.
  while (workInProgress !== null) {
    performUnitOfWork(workInProgress);
  }
}
---
function workLoopConcurrent(nonIdle: boolean) {
  // We yield every other "frame" when rendering Transition or Retries. Those are blocking
  // revealing new content. The purpose of this yield is not to avoid the overhead of yielding,
  // which is very low, but rather to intentionally block any frequently occuring other main
  // thread work like animations from starving our work. In other words, the purpose of this
  // is to reduce the framerate of animations to 30 frames per second.
  // For Idle work we yield every 5ms to keep animations going smooth.
  if (workInProgress !== null) {
    const yieldAfter = now() + (nonIdle ? 25 : 5);
    do {
      // $FlowFixMe[incompatible-call] flow doesn't know that now() is side-effect free
      performUnitOfWork(workInProgress);
    } while (workInProgress !== null && now() < yieldAfter);
  }
}
---
/** @noinline */
function workLoopConcurrentByScheduler() {
  // Perform work until Scheduler asks us to yield
  while (workInProgress !== null && !shouldYield()) {
    // $FlowFixMe[incompatible-call] flow doesn't know that shouldYield() is side-effect free
    performUnitOfWork(workInProgress);
  }
}
```

- workLoopSync を呼び出しているのが renderRootSync
- renderRootSync を呼び出しているのが performSyncWorkOnRoot
- performSyncWorkOnRoot を呼び出しているのが flushSyncWorkAcrossRoots_impl
- flushSyncWorkAcrossRoots_impl を呼び出しているのが flushSyncWorkOnAllRoots
- flushSyncWorkOnAllRoots を呼び出しているのが flushRoot
- flushRoot を呼び出しているのが attemptSynchronousHydration
- attemptSynchronousHydration を呼び出しているのが dispatchEvent
  - ReactDomeEventListener.js に DispatchEvent が存在する
- dispatchEvent を呼び出しているのが createEventListenerWrapper

- 次何しよう？？

- createRoot から見ていく

ReactDOMRoot.js

```js
export function createRoot(
  container: Element | Document | DocumentFragment,
  options?: CreateRootOptions
): RootType {
  if (!isValidContainer(container)) {
    throw new Error("Target container is not a DOM element.");
  }

  warnIfReactDOMContainerInDEV(container);

  const concurrentUpdatesByDefaultOverride = false;
  let isStrictMode = false;
  let identifierPrefix = "";
  let onUncaughtError = defaultOnUncaughtError;
  let onCaughtError = defaultOnCaughtError;
  let onRecoverableError = defaultOnRecoverableError;
  let onDefaultTransitionIndicator = defaultOnDefaultTransitionIndicator;
  let transitionCallbacks = null;

  if (options !== null && options !== undefined) {
    if (options.unstable_strictMode === true) {
      isStrictMode = true;
    }
    if (options.identifierPrefix !== undefined) {
      identifierPrefix = options.identifierPrefix;
    }
    if (options.onUncaughtError !== undefined) {
      onUncaughtError = options.onUncaughtError;
    }
    if (options.onCaughtError !== undefined) {
      onCaughtError = options.onCaughtError;
    }
    if (options.onRecoverableError !== undefined) {
      onRecoverableError = options.onRecoverableError;
    }
    if (enableDefaultTransitionIndicator) {
      if (options.onDefaultTransitionIndicator !== undefined) {
        onDefaultTransitionIndicator = options.onDefaultTransitionIndicator;
      }
    }
    if (options.unstable_transitionCallbacks !== undefined) {
      transitionCallbacks = options.unstable_transitionCallbacks;
    }
  }

  const root = createContainer(
    container,
    ConcurrentRoot,
    null,
    isStrictMode,
    concurrentUpdatesByDefaultOverride,
    identifierPrefix,
    onUncaughtError,
    onCaughtError,
    onRecoverableError,
    onDefaultTransitionIndicator,
    transitionCallbacks
  );
  markContainerAsRoot(root.current, container);

  const rootContainerElement: Document | Element | DocumentFragment =
    !disableCommentsAsDOMContainers && container.nodeType === COMMENT_NODE
      ? (container.parentNode: any)
      : container;
  listenToAllSupportedEvents(rootContainerElement);

  // $FlowFixMe[invalid-constructor] Flow no longer supports calling new on functions
  return new ReactDOMRoot(root);
}
```

- createContainer を探す

```js
export function createContainer(
  containerInfo: Container,
  tag: RootTag,
  hydrationCallbacks: null | SuspenseHydrationCallbacks,
  isStrictMode: boolean,
  // TODO: Remove `concurrentUpdatesByDefaultOverride`. It is now ignored.
  concurrentUpdatesByDefaultOverride: null | boolean,
  identifierPrefix: string,
  onUncaughtError: (
    error: mixed,
    errorInfo: {+componentStack?: ?string},
  ) => void,
  onCaughtError: (
    error: mixed,
    errorInfo: {
      +componentStack?: ?string,
      +errorBoundary?: ?component(...props: any),
    },
  ) => void,
  onRecoverableError: (
    error: mixed,
    errorInfo: {+componentStack?: ?string},
  ) => void,
  onDefaultTransitionIndicator: () => void | (() => void),
  transitionCallbacks: null | TransitionTracingCallbacks,
): OpaqueRoot {
  const hydrate = false;
  const initialChildren = null;
  const root = createFiberRoot(
    containerInfo,
    tag,
    hydrate,
    initialChildren,
    hydrationCallbacks,
    isStrictMode,
    identifierPrefix,
    null,
    onUncaughtError,
    onCaughtError,
    onRecoverableError,
    onDefaultTransitionIndicator,
    transitionCallbacks,
  );
  registerDefaultIndicator(onDefaultTransitionIndicator);
  return root;
}
```

- 次は createFiberRoot

```
⏺ createFiberRoot関数は、Reactの中核となるFiberツリーのルートを作成する重要な初期化処理です。

  初期化されるデータ構造:

  1. FiberRootNode - アプリケーション全体のコンテナ
    - レーンベースの優先度システム（pendingLanes、suspendedLanesなど）
    - エラーハンドリング用コールバック
    - キャッシュシステム（pooledCache）
  2. HostRootFiber - Fiberツリーのエントリーポイント
  3. 初期キャッシュ - パフォーマンス最適化用
  4. 更新キュー - 状態更新管理用

  この構造になる理由:

  - 関心の分離: コンテナレベル（スケジューリング）とツリー構造（調整）を分離
  - 双方向参照: root.current = fiber、fiber.stateNode = rootで効率的な相互アクセス
  - 並行レンダリング対応: レーンベースの優先度システムで時分割処理を実現

  この初期化により、React全体の動作（更新スケジューリング、エラー処理、キャッシュ管理）を制御する中枢が確立されます。
```

```
⏺ レーンとは：
  レーンは32ビットの数値（ビットフラグ）で、作業の優先度を表します。

  // 実際のレーン定義例
  SyncLane = 0b010           // 最高優先度（ユーザー入力など）
  DefaultLane = 0b100000     // 通常優先度
  TransitionLane = 0b0100000000  // 低優先度（トランジション）

  - 小さい数値 = 高優先度
  - ビット演算で複数レーンを組み合わせ可能（|で結合）
  - React が「どの作業を先にやるか」を決める仕組み

  Fiberツリーのエントリーポイント：
  HostRootFiberがコンポーネントツリーの開始点。Reactはここから子コンポーネントを辿って更新処理を行います。

  コンテナ vs ツリーの違い：

  - FiberRoot（コンテナ）:
    - React アプリ全体の管理者
    - スケジューリング、DOM参照、エラー処理を担当
    - document.getElementById('root')への参照も持つ
  - HostRootFiber（ツリー）:
    - 実際のコンポーネントツリーの頂点
    - <App /> などのコンポーネントの親にあたる
    - 調整（reconciliation）処理に参加する実際のFiberノード

  なぜ分離？
  管理業務（スケジューリング）と実際のコンポーネント処理を分けることで、Reactが効率的に並行レンダリングできるようになっています。
```

```js
// index.tsx

const root = ReactDOM.createRoot(
  document.getElementById("root") as HTMLElement
);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// createRootの引数は<div id=root></div>のようなHTMLElement
// createRootの返り値は ReactDOMRootでwrapされたOpaqueRoot(FiberRootのtype alias)
// createRoot -> createContainer -> createFiberRoot->
// createFiberRootでは new FiberRootNodeでFiberRootを作成し、root.currentやcache,memorizedState,initializeUpdateQueue()の実行を行って、rootを返却
// root.currentの実態はcreateHostRootFiberで作成されたFiberが入る
// 上記FiberはWorkTagがHostRoot
```

```js
function ReactDOMRoot(internalRoot: FiberRoot) {
  this._internalRoot = internalRoot;
}

// childrenはおそらく
// <App>...</App>のこと
ReactDOMHydrationRoot.prototype.render = ReactDOMRoot.prototype.render =
  // $FlowFixMe[missing-this-annot]
  function (children: ReactNodeList): void {
    const root = this._internalRoot;
    if (root === null) {
      throw new Error("Cannot update an unmounted root.");
    }

    updateContainer(children, root, null, null);
  };
```

- 次は updateContainer から

```js
export function updateContainer(
  element: ReactNodeList,
  container: OpaqueRoot,
  parentComponent: ?component(...props: any),
  callback: ?Function,
): Lane {
  const current = container.current;
  const lane = requestUpdateLane(current);
  updateContainerImpl(
    current,
    lane,
    element,
    container,
    parentComponent,
    callback,
  );
  return lane;
}
```

-

```js

function updateContainerImpl(
  rootFiber: Fiber,
  lane: Lane,
  element: ReactNodeList,
  container: OpaqueRoot,
  parentComponent: ?component(...props: any),
  callback: ?Function,
): void {
  if (enableSchedulingProfiler) {
    markRenderScheduled(lane);
  }

  const context = getContextForSubtree(parentComponent);
  if (container.context === null) {
    container.context = context;
  } else {
    container.pendingContext = context;
  }

  const update = createUpdate(lane);
  // Caution: React DevTools currently depends on this property
  // being called "element".
  update.payload = {element};

  callback = callback === undefined ? null : callback;
  if (callback !== null) {
    update.callback = callback;
  }

  const root = enqueueUpdate(rootFiber, update, lane);
  if (root !== null) {
    startUpdateTimerByLane(lane, 'root.render()', null);
    scheduleUpdateOnFiber(root, rootFiber, lane);
    entangleTransitions(root, rootFiber, lane);
  }
}
```

- getContextForSubtree

```js
function getContextForSubtree(
  parentComponent: ?component(...props: any),
): Object {
  if (!parentComponent) {
    return emptyContextObject;
  }

  const fiber = getInstance(parentComponent);
  const parentContext = findCurrentUnmaskedContext(fiber);

  if (fiber.tag === ClassComponent) {
    const Component = fiber.type;
    if (isLegacyContextProvider(Component)) {
      return processChildContext(fiber, Component, parentContext);
    }
  }

  return parentContext;
}
```

```js
export function startUpdateTimerByLane(
  lane: Lane,
  method: string,
  fiber: Fiber | null
): void {
  if (!enableProfilerTimer || !enableComponentPerformanceTrack) {
    return;
  }
  if (isGestureRender(lane)) {
    if (gestureUpdateTime < 0) {
      gestureUpdateTime = now();
      gestureUpdateTask = createTask(method);
      gestureUpdateMethodName = method;
      if (__DEV__ && fiber != null) {
        gestureUpdateComponentName = getComponentNameFromFiber(fiber);
      }
      const newEventTime = resolveEventTimeStamp();
      const newEventType = resolveEventType();
      if (
        newEventTime !== gestureEventRepeatTime ||
        newEventType !== gestureEventType
      ) {
        gestureEventRepeatTime = -1.1;
      }
      gestureEventTime = newEventTime;
      gestureEventType = newEventType;
    }
  } else if (isBlockingLane(lane)) {
    if (blockingUpdateTime < 0) {
      blockingUpdateTime = now();
      blockingUpdateTask = createTask(method);
      blockingUpdateMethodName = method;
      if (__DEV__ && fiber != null) {
        blockingUpdateComponentName = getComponentNameFromFiber(fiber);
      }
      if (isAlreadyRendering()) {
        componentEffectSpawnedUpdate = true;
        blockingUpdateType = SPAWNED_UPDATE;
      }
      const newEventTime = resolveEventTimeStamp();
      const newEventType = resolveEventType();
      if (
        newEventTime !== blockingEventRepeatTime ||
        newEventType !== blockingEventType
      ) {
        blockingEventRepeatTime = -1.1;
      } else if (newEventType !== null) {
        // If this is a second update in the same event, we treat it as a spawned update.
        // This might be a microtask spawned from useEffect, multiple flushSync or
        // a setState in a microtask spawned after the first setState. Regardless it's bad.
        blockingUpdateType = SPAWNED_UPDATE;
      }
      blockingEventTime = newEventTime;
      blockingEventType = newEventType;
    }
  } else if (isTransitionLane(lane)) {
    if (transitionUpdateTime < 0) {
      transitionUpdateTime = now();
      transitionUpdateTask = createTask(method);
      transitionUpdateMethodName = method;
      if (__DEV__ && fiber != null) {
        transitionUpdateComponentName = getComponentNameFromFiber(fiber);
      }
      if (transitionStartTime < 0) {
        const newEventTime = resolveEventTimeStamp();
        const newEventType = resolveEventType();
        if (
          newEventTime !== transitionEventRepeatTime ||
          newEventType !== transitionEventType
        ) {
          transitionEventRepeatTime = -1.1;
        }
        transitionEventTime = newEventTime;
        transitionEventType = newEventType;
      }
    }
  }
}
```
