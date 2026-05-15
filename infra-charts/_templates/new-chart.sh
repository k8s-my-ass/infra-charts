#!/usr/bin/env bash
# new-chart.sh - генератор нового Helm-чарта для infra-charts
# Usage: ./new-chart.sh <category> <name>
# Example: ./new-chart.sh data clickhouse

set -euo pipefail

CATEGORY="${1:-}"
NAME="${2:-}"

if [ -z "$CATEGORY" ] || [ -z "$NAME" ]; then
    echo "Usage: $0 <category> <chart-name>"
    echo "Example: $0 data clickhouse"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHART_DIR="$ROOT_DIR/$CATEGORY/$NAME"

if [ -d "$CHART_DIR" ]; then
    echo "❌ Error: $CHART_DIR already exists"
    exit 1
fi

mkdir -p "$CHART_DIR"

cat > "$CHART_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: $NAME
description: |
  $(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
  managed via infra-charts GitOps platform.
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies: []
EOF

cat > "$CHART_DIR/values.common.yaml" <<EOF
# Общие значения для всех окружений.
# Переопределяйте в values.<env>.yaml для конкретного окружения.

$NAME:
  enabled: true

  replicaCount: 1

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

  nodeSelector: {}
  tolerations: []
  affinity: {}

  persistence:
    enabled: false
    storageClass: ""   # пусто = default StorageClass
    size: 10Gi

  serviceAccount:
    create: true
    annotations: {}

  ingress:
    enabled: false
    className: istio
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: $NAME.local
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: $NAME-tls
        hosts:
          - $NAME.local
EOF

cat > "$CHART_DIR/values.test.yaml" <<EOF
# Переопределения для test (dev/staging) окружения
$NAME:
  replicaCount: 1

  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

  ingress:
    enabled: true
    hosts:
      - host: $NAME.test.example.com
EOF

cat > "$CHART_DIR/README.md" <<EOF
# $NAME

$(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1') - компонент категории \`$CATEGORY\`.

## Категория
\`$CATEGORY\`

## Назначение
Описание компонента и его роль в платформе.

## Зависимости
- Указать upstream-чарт / operator
- Указать зависимости от других категорий (например, требует \`storage/openebs\`)

## Структура
- \`Chart.yaml\` - метаданные и зависимости
- \`values.common.yaml\` - базовые значения
- \`values.<env>.yaml\` - переопределения под окружение

## Установка (ручная)
\`\`\`bash
helm dependency update
helm upgrade --install $NAME . -f values.common.yaml -f values.test.yaml --namespace $CATEGORY --create-namespace
\`\`\`

## Переопределения
Все кастомизации - через \`values.<env>.yaml\`. Не редактируйте upstream-чарт.
EOF

echo "✅ Created chart: $CHART_DIR"
echo "   Files: Chart.yaml, values.common.yaml, values.test.yaml, README.md"
echo "   Next: add upstream dependency to Chart.yaml and run 'helm dependency update'"
