# 手動編集による React Debug セットアップ

## 🎯 作業の流れ

### 1. 最初から始める場合
```bash
# Reactリポジトリをクローン
git clone https://github.com/facebook/react.git
cd react

# 依存関係をインストール
yarn install
```

### 2. 途中から始める場合（既にクローン済み）
```bash
cd react

# 現在の変更を確認
git status

# 必要に応じて変更を破棄
git checkout -- .

# または、変更を保存したい場合
git stash
```

### 3. ソースコードを手動編集

#### 📝 編集ファイル 1: `packages/react-dom/src/client/ReactDOMRoot.js`

**A. createRoot関数（175行目付近）**
```javascript
// BEFORE:
export function createRoot(
  container: Element | Document | DocumentFragment,
  options?: CreateRootOptions,
): RootType {
  if (!isValidContainer(container)) {

// AFTER:
export function createRoot(
  container: Element | Document | DocumentFragment,
  options?: CreateRootOptions,
): RootType {
  console.log('🚀 [React Debug] createRoot called with container:', container, 'options:', options);
  
  if (!isValidContainer(container)) {
```

**B. render関数（109行目付近）**
```javascript
// BEFORE:
// $FlowFixMe[missing-this-annot]
function (children: ReactNodeList): void {
  const root = this._internalRoot;

// AFTER:
// $FlowFixMe[missing-this-annot]
function (children: ReactNodeList): void {
  console.log('🎯 [React Debug] root.render called with children:', children);
  
  const root = this._internalRoot;
```

**C. updateContainer呼び出し前後（137行目付近）**
```javascript
// BEFORE:
    }
    updateContainer(children, root, null, null);
  };

// AFTER:
    }
    console.log('📝 [React Debug] updateContainer about to be called with root:', root);
    updateContainer(children, root, null, null);
    console.log('✅ [React Debug] updateContainer completed');
  };
```

### 4. Reactをビルド
```bash
# Reactリポジトリのルートで実行
RELEASE_CHANNEL=experimental yarn build react/index,react/jsx,react-dom/index,react-dom/client --type=NODE
```

### 5. DOM fixtureのセットアップ
```bash
cd fixtures/dom
yarn install
cp -a ../../build/oss-experimental/. node_modules/
```

#### 📝 編集ファイル 2: `fixtures/dom/src/react-loader.js`

**react-loader.js の修正（136-143行目付近）**
```javascript
// BEFORE:
  } else {
    throw new Error(
      'This fixture no longer works with local versions. Provide a version query parameter that matches a version published to npm to use the fixture.'
    );
  }

// AFTER:
  } else {
    // ローカルビルドのパスを設定
    reactPath = '/react/index.js';
    reactDOMPath = '/react-dom/index.js';
    reactDOMClientPath = '/react-dom/client.js';
    needsReactDOM = true;
    usingModules = false;
  }
```

### 6. サーバー起動
```bash
# fixtures/dom ディレクトリで実行
yarn dev
```

### 7. ブラウザで確認
- http://localhost:3000 を開く
- 開発者ツールのConsoleでログを確認

## 🔄 再編集する場合

### A. ソースコードだけ変更したい場合
1. `packages/react-dom/src/client/ReactDOMRoot.js` を編集
2. 手順4（ビルド）から再実行

### B. 完全にやり直したい場合
1. 変更を破棄: `git checkout -- .`
2. 手順3（編集）から再実行

### C. 別のファイルも編集したい場合
1. 新しいファイルを編集
2. 手順4（ビルド）から再実行

## 💡 おすすめワークフロー

### 初回
```bash
cd react
# 1. 手動でファイル編集
# 2. ビルド
RELEASE_CHANNEL=experimental yarn build react/index,react/jsx,react-dom/index,react-dom/client --type=NODE
# 3. DOM fixture セットアップ
cd fixtures/dom && yarn install && cp -a ../../build/oss-experimental/. node_modules/
# 4. react-loader.js を手動編集
# 5. 起動
yarn dev
```

### 2回目以降（ソースコードのみ変更）
```bash
cd react
# 1. ReactDOMRoot.js を編集
# 2. ビルド
RELEASE_CHANNEL=experimental yarn build react/index,react/jsx,react-dom/index,react-dom/client --type=NODE
# 3. コピー
cd fixtures/dom && cp -a ../../build/oss-experimental/. node_modules/
# 4. 起動（既に起動中なら自動リロード）
yarn dev
```

## 🧹 クリーンアップ

完全に元に戻したい場合：
```bash
cd react
git checkout -- .
rm -rf build/
cd fixtures/dom
git checkout -- .
rm -rf node_modules/
yarn install
```