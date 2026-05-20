# 議事録作成 BOT — DSL エクスポート手順

NKP カタログは **Kubernetes / Helm のデプロイ**を再現します。  
Dify 上で作成した BOT（ワークフロー・プロンプト）は **PostgreSQL 内のデータ**のため、別途 DSL としてエクスポートし、同梱してください。

## 1. Dify UI からエクスポート

1. Dify にログイン
2. 議事録作成 BOT のアプリを開く
3. **エクスポート DSL**（Studio メニューまたはオーケストレーション画面）
4. 保存した YAML をこのディレクトリに配置する

```text
0520/dify/catalog/apps/gijiroku-bot.dsl.yaml   ← 任意のファイル名で可
```

> API キー・ナレッジベースの実データは DSL に含まれません。  
> Ollama の Base URL はインポート後に再設定が必要な場合があります。

## 2. Ollama モデルプロバイダ（参照値）

| 項目 | 値 |
|------|-----|
| タイプ | Ollama |
| Base URL | `http://ollama.ollama.svc.cluster.local:11434` |
| モデル名 | `7shi/ezo-gemma-2-jpn:2b-instruct-q8_0` |

カタログで Ollama を **ワークスペース namespace** に入れた場合は、次の形式に読み替えます。

```text
http://ollama.<ワークスペース-namespace>.svc.cluster.local:11434
```

## 3. インポート（手動）

1. カタログから Dify をデプロイ
2. Dify UI → **DSL インポート** で `gijiroku-bot.dsl.yaml` を読み込む
3. モデルプロバイダの接続テストを実行

## 4. インポート（API・任意）

```bash
# 例: 管理者トークンと Dify API の URL を設定
export DIFY_CONSOLE_URL="https://<dify-host>/console/api"
export DIFY_TOKEN="<console-api-token>"
export DSL_FILE="0520/dify/catalog/apps/gijiroku-bot.dsl.yaml"

curl -sS -X POST "${DIFY_CONSOLE_URL}/apps/import" \
  -H "Authorization: Bearer ${DIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --rawfile yaml "${DSL_FILE}" '{mode:"yaml-content", yaml_content:$yaml}')"
```

レスポンスに `import_id` がある場合は、Dify のドキュメントに従い confirm エンドポイントを呼び出してください。
