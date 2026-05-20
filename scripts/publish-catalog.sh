#!/usr/bin/env bash
# Dify + Ollama カタログ用チャートを GHCR に push し、バンドルを作成する。
set -euo pipefail

ROOT="${HOME}/nutanix"
DIFY_CHART="${ROOT}/0520/dify"
OLLAMA_CHART="${ROOT}/ollama-helm"
REGISTRY="oci://ghcr.io/yukinarai"

echo "==> Dify chart package & push (0.2.0)"
cd "${DIFY_CHART}"
helm package .
helm push dify-0.2.0.tgz "${REGISTRY}/"

echo "==> Ollama chart package & push (1.56.0)"
cd "${OLLAMA_CHART}"
helm package .
# Chart.yaml の version に合わせる（例: ollama-1.56.0.tgz）
Tgz=(ollama-*.tgz)
helm push "${Tgz[0]}" "${REGISTRY}/"

echo "==> Catalog bundle (dify + ollama)"
cd "${ROOT}"
nkp create catalog-bundle \
  --repo-dir . \
  --apps dify=1.11.5,ollama=0.23.2 \
  --collection-tag gijiroku-solution

echo "==> Done. Next:"
echo "  nkp push bundle --bundle <出力tar> --to-registry ${REGISTRY}/"
echo "  nkp create catalog-application --url ${REGISTRY}/nutanix/<collection> --tag <tag> --workspace <ws>"
