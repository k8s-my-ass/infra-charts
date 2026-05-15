# Justfile для управления enterprise infra-charts
# Установка: https://github.com/casey/just

_default:
    @just --list

# =====================
# ЗАВИСИМОСТИ
# =====================

update-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    for chart in $(find . -name Chart.yaml -not -path "./argo-cd-apps/*" -not -path "./_templates/*"); do
        dir=$(dirname "$chart")
        echo "  → $dir"
        (cd "$dir" && helm dependency update >/dev/null 2>&1 || echo "    ⚠️ failed: $dir")
    done

update-deps-one CHART:
    cd "{{CHART}}" && helm dependency update

# =====================
# ВАЛИДАЦИЯ
# =====================

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for chart in $(find . -name Chart.yaml -not -path "./argo-cd-apps/*" -not -path "./_templates/*"); do
        dir=$(dirname "$chart")
        helm lint "$dir" -f "$dir/values.common.yaml" || failed=$((failed + 1))
    done
    [ $failed -eq 0 ] && echo "✅ All charts passed lint" || { echo "❌ $failed failed"; exit 1; }

lint-one CHART:
    helm lint "{{CHART}}" -f "{{CHART}}/values.common.yaml"

template CHART ENV="test":
    helm template "{{CHART}}" "{{CHART}}" \
        -f "{{CHART}}/values.common.yaml" \
        -f "{{CHART}}/values.{{ENV}}.yaml" \
        --namespace "{{CHART}}"

# =====================
# ANSIBLE BOOTSTRAP
# =====================

bootstrap-argo ENV:
    ansible-playbook -i ansible/inv-"{{ENV}}" ansible/install-argo.yaml -D

# =====================
# ГЕНЕРАЦИЯ
# =====================

new-chart CATEGORY NAME:
    ./infra-charts/_templates/new-chart.sh "{{CATEGORY}}" "{{NAME}}"

# =====================
# УТИЛИТЫ
# =====================

cleanup:
    #!/usr/bin/env bash
    find . -type d -name charts -exec rm -rf {} + 2>/dev/null || true
    find . -name Chart.lock -delete 2>/dev/null || true
    echo "Cleaned up"
