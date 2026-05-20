# NKP カタログ化手順 — Dify 議事録BOT + Ollama

議事録作成 BOT（Ollama モデル利用）を、他のワークスペースでも再現できるよう NKP カタログに載せる手順です。

---

## カタログに含まれるもの / 含まれないもの

| 含まれる（Helm / カタログ） | 含まれない（別途エクスポート） |
|----------------------------|------------------------------|
| Dify CE（PostgreSQL / Redis / Weaviate 等） | BOT のワークフロー・プロンプト本体 |
| Ollama サーバー + 既定モデルの pull | Dify ユーザーアカウント |
| ストレージ・Traefik 等の既定 values | Ollama プロバイダの検証済みトークン |

**BOT 本体**は Dify UI から **DSL エクスポート**し、`0520/dify/catalog/apps/` に保存して Git 管理してください（手順は [catalog/apps/README.md](dify/catalog/apps/README.md)）。

---

## ディレクトリ構成（本リポジトリ）

```text
/home/nutanix/
├── applications/
│   ├── dify/1.11.5/          # Dify カタログ定義
│   └── ollama/0.23.2/        # Ollama カタログ定義
├── 0520/dify/                # Dify Helm チャート（0.2.0）
├── ollama-helm/              # Ollama Helm チャート（push 用）
└── 0520/scripts/publish-catalog.sh
```

---

## 手順 1: 議事録 BOT の DSL をエクスポート

1. 稼働中の Dify で議事録 BOT を開く  
2. **エクスポート DSL** で YAML をダウンロード  
3. 次のパスに保存（コミット推奨）

   `0520/dify/catalog/apps/gijiroku-bot.dsl.yaml`

---

## 手順 2: Helm チャートを GHCR に push

### 2.1 認証

```bash
export GHCR_USER=yukinarai
export GHCR_PAT=<GitHub PAT>
echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
```

### 2.2 Dify チャート（0.2.0）

```bash
cd /home/nutanix/0520/dify
helm package .
helm push dify-0.2.0.tgz oci://ghcr.io/yukinarai/
# → ghcr.io/yukinarai/dify:0.2.0
```

**解説:** カタログの `OCIRepository` は `oci://ghcr.io/yukinarai/dify` タグ `0.2.0` を参照します。

### 2.3 Ollama チャート（otwld/ollama-helm）

```bash
cd /home/nutanix/ollama-helm
helm package .
helm push ollama-1.56.0.tgz oci://ghcr.io/yukinarai/
# → ghcr.io/yukinarai/ollama:1.56.0
```

**解説:** カタログ側 `ref.tag` はチャートの `version`（`1.56.0`）です。`appVersion` の `0.23.2` とは別です。

一括実行する場合:

```bash
chmod +x /home/nutanix/0520/scripts/publish-catalog.sh
/home/nutanix/0520/scripts/publish-catalog.sh
```

---

## 手順 3: カタログバンドル作成

```bash
cd /home/nutanix
nkp create catalog-bundle \
  --repo-dir . \
  --apps dify=1.11.5,ollama=0.23.2 \
  --collection-tag gijiroku-solution
```

| オプション | 解説 |
|------------|------|
| `--apps dify=1.11.5,ollama=0.23.2` | 2 アプリを1コレクションにまとめる |
| `--collection-tag gijiroku-solution` | 複数アプリ時に必須のコレクション識別子 |

成功すると `dify-1.11.5.tar` 等が生成されます（コレクション名によりファイル名は異なる場合あり）。

```bash
nkp push bundle --bundle <生成されたtar> --to-registry oci://ghcr.io/yukinarai/
```

---

## 手順 4: ワークスペースへカタログ登録

### 4.1 個別に登録する場合

**Ollama（先にデプロイ推奨）**

```bash
nkp create catalog-application \
  --url oci://ghcr.io/yukinarai/nutanix/ollama \
  --tag 0.23.2 \
  --workspace <ワークスペース名> \
  --skip-oci-registry-patches
```

**Dify**

```bash
nkp create catalog-application \
  --url oci://ghcr.io/yukinarai/nutanix/dify \
  --tag 1.11.5 \
  --workspace <ワークスペース名> \
  --skip-oci-registry-patches
```

> `--url` に `:タグ` を付けないこと。タグは `--tag` で指定。

### 4.2 コレクションとして登録する場合

push 後に NKP が案内する `nutanix/<collection>` URL とタグを使用します。

---

## 手順 5: デプロイ後の設定

### 5.1 Ollama 接続確認

```bash
export KUBECONFIG=/home/nutanix/work/yukicluster-kubeconfig.conf
kubectl get pods,svc -n ollama
kubectl exec deploy/ollama -n ollama -- ollama list
```

### 5.2 Dify で Ollama モデルプロバイダ

| 項目 | 値 |
|------|-----|
| Base URL | `http://ollama.ollama.svc.cluster.local:11434` |
| モデル | `7shi/ezo-gemma-2-jpn:2b-instruct-q8_0` |

### 5.3 議事録 BOT の DSL インポート

[catalog/apps/README.md](dify/catalog/apps/README.md) を参照。

### 5.4 プライベートイメージを使う場合

```bash
kubectl create secret docker-registry dockerhub-cred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<user> \
  --docker-password='<password>' \
  -n <ワークスペース-namespace>

kubectl patch serviceaccount default \
  -n <ワークスペース-namespace> \
  -p '{"imagePullSecrets":[{"name":"dockerhub-cred"}]}'
```

---

## 既存デプロイ（1.11.5 / chart 0.1.0）からの更新

すでに `nutanix-dify` カタログアプリをデプロイ済みの場合:

1. 上記手順で chart `0.2.0` を push  
2. カタログバンドルを再作成・再 push  
3. Kommander / NKP UI から Dify アプリを **アップグレード**（または HelmRelease の chart tag を `0.2.0` に更新）  
4. DSL を再インポート（必要な場合）

---

## トラブルシュート

| 現象 | 対処 |
|------|------|
| `ollama.ollama.svc.cluster.local` が解決できない | Dify と Ollama が **同一クラスタ**か確認。別クラスタの場合は到達可能な URL を指定 |
| カタログ bundle で OCI pull 失敗 | `helmrelease.yaml` の `url` にチャート名まで含める（例: `.../dify`） |
| BOT だけ消えた | DSL から再インポート。カタログはインフラのみ |

---

## 参考

- 本日の作業ログ: [作業手順_2026-05-20.md](作業手順_2026-05-20.md)
- Dify 設計: [dify/design_spec_dify_on_nkp.md](dify/design_spec_dify_on_nkp.md)

---

*更新: 2026-05-20*
