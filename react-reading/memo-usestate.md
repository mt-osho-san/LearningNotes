- packages/react/index.jsでuseStateがre exportされている感じ

```js
export function useState<S>(
  initialState: (() => S) | S,
): [S, Dispatch<BasicStateAction<S>>] {
  const dispatcher = resolveDispatcher();
  return dispatcher.useState(initialState);
}

// Aを受け取って何も返さない関数
type Dispatch<A> = A => void;

// 更新関数
type BasicStateAction<S> = (S => S) | S;

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
    init?: (I) => S,
  ): [S, Dispatch<A>],
  useContext<T>(context: ReactContext<T>): T,
  useRef<T>(initialValue: T): {current: T},
  useEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null,
  ): void,
  // TODO: Non-nullable once `enableUseEffectEventHook` is on everywhere.
  useEffectEvent?: <Args, F: (...Array<Args>) => mixed>(callback: F) => F,
  useInsertionEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null,
  ): void,
  useLayoutEffect(
    create: () => (() => void) | void,
    deps: Array<mixed> | void | null,
  ): void,
  useCallback<T>(callback: T, deps: Array<mixed> | void | null): T,
  useMemo<T>(nextCreate: () => T, deps: Array<mixed> | void | null): T,
  useImperativeHandle<T>(
    ref: {current: T | null} | ((inst: T | null) => mixed) | null | void,
    create: () => T,
    deps: Array<mixed> | void | null,
  ): void,
  useDebugValue<T>(value: T, formatterFn: ?(value: T) => mixed): void,
  useDeferredValue<T>(value: T, initialValue?: T): T,
  useTransition(): [
    boolean,
    (callback: () => void, options?: StartTransitionOptions) => void,
  ],
  useSyncExternalStore<T>(
    subscribe: (() => void) => () => void,
    getSnapshot: () => T,
    getServerSnapshot?: () => T,
  ): T,
  useId(): string,
  useCacheRefresh: () => <T>(?() => T, ?T) => void,
  useMemoCache: (size: number) => Array<any>,
  useHostTransitionStatus: () => TransitionStatus,
  useOptimistic: <S, A>(
    passthrough: S,
    reducer: ?(S, A) => S,
  ) => [S, (A) => void],
  useFormState: <S, P>(
    action: (Awaited<S>, P) => S,
    initialState: Awaited<S>,
    permalink?: string,
  ) => [Awaited<S>, (P) => void, boolean],
  useActionState: <S, P>(
    action: (Awaited<S>, P) => S,
    initialState: Awaited<S>,
    permalink?: string,
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
