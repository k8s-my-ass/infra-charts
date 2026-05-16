# infra-charts

Единый репозиторий Helm-чартов для развёртывания enterprise Kubernetes-платформы через GitOps (ArgoCD).

## Архитектура

Репозиторий организован по принципу **слои абстракции**: каждая директория отвечает за изолированную функциональную зону.

## Структура

```plaintext
infra-charts/
├── argo-cd-apps/           # Корневой GitOps-конвейер
├── backup-dr/              # Резервное копирование и DR
├── chaos/                  # Chaos Engineering
├── core/                   # Критическая инфраструктура (bootstrap)
├── data/                   # Stateful-приложения
├── devtools/               # Инструменты цепочки поставки
├── finops/                 # Управление затратами
├── gateways/               # L7 API Gateways
├── gitops/                 # Расширение ArgoCD
├── iam/                    # Identity & Access Management
├── network/                # CNI, Service Mesh, DNS
├── observability/          # Метрики, логи, трейсы
├── platform/               # Платформенные сервисы
├── security/               # Runtime security, policies
├── storage/                # CSI и хранилища
├── global-values/          # Общие константы
└── _templates/             # Шаблоны генерации
```

## k3s на VPS

На k3s встроен **Klipper Service LB**. Istio Gateway `type: LoadBalancer` получает IP VPS автоматически. MetalLB не нужен.

## Локальная работа

```bash
just update-deps # обновить зависимости
just lint # линт всех чартов
just new-chart data clickhouse # создать чарт
just bootstrap-argo # bootstrap через Ansible
```
