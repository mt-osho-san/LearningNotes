#!/bin/bash

# Quick Rebuild Script
# ソースコードを編集した後の再ビルド用スクリプト

set -e  # エラーが発生したら停止

echo "⚡ Quick Rebuild を開始します..."


echo "🔨 Reactを再ビルド中..."
RELEASE_CHANNEL=experimental yarn build react/index,react/jsx,react-dom/index,react-dom/client --type=NODE

echo "📋 DOM fixtureに再コピー中..."
cd fixtures/dom
cp -a ../../build/oss-experimental/. node_modules/

yarn dev
