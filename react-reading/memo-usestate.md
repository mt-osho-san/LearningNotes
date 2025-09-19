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
