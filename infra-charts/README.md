# infra-charts

Единый репозиторий Helm-чартов для развёртывания enterprise Kubernetes-платформы через GitOps (ArgoCD).

## Архитектура

Репозиторий организован по принципу **слои абстракции**: каждая директория отвечает за изолированную функциональную зону. Это позволяет:

- Назначать разные команды ответственными за разные слои (Platform, Security, SRE, Data)
- Применять независимые циклы релизов и окружения
- Масштабировать платформу без редизайна структуры

## Структура репозитория

```bash
ansible/
├── install-argo.yaml       # Плейбук с установкой argo-cd
├── inv-prod.yaml           # Инвентарник для прод-окружения
├── inv-test.yaml           # Инвентарник для тестового окружения
├── venv-requirements.txt   # Ansible-модули
infra-charts/
├── argo-cd-apps/           # Корневой GitOps-конвейер (ApplicationSet'ы)
├── backup-dr/              # Резервное копирование и аварийное восстановление
├── chaos/                  # Chaos Engineering
├── core/                   # Критическая инфраструктура кластера (bootstrap)
├── data/                   # Stateful-приложения: БД, кэши, брокеры, OLAP
├── devtools/               # Инструменты цепочки поставки ПО
├── finops/                 # Управление затратами и ресурсами
├── gateways/               # L7 API Gateways и ingress-контроллеры
├── gitops/                 # Расширение ArgoCD: progressive delivery, workflows
├── iam/                    # Identity & Access Management (SSO, OIDC)
├── network/                # CNI, Service Mesh, DNS, L2/L3 балансировка
├── observability/          # Метрики, логи, трейсы, профилирование, on-call
├── platform/               # Платформенные сервисы: CI/CD, serverless, autoscaling
├── security/               # Runtime security, supply chain, policies, secrets
├── storage/                # CSI-драйверы и блочное/файловое/Object хранилище
├── global-values/          # Общие значения для всех окружений
├── _templates/             # Шаблоны для генерации новых чартов
└── justfile                # Команды для локальной работы
```

## Критерии разделения по категориям

| Категория         | Критерий                                                                   | Примеры                              |
| ----------------- | -------------------------------------------------------------------------- | ------------------------------------ |
| **storage**       | Инфраструктура подложки: CSI, диски, тома, snapshots. "Железо под БД".     | OpenEBS, Rook-Ceph, TopoLVM          |
| **data**          | Stateful-приложения с собственным протоколом, используемые бизнес-логикой. | PostgreSQL, Kafka, ClickHouse, Redis |
| **gateways**      | L7 прокси с API-management (rate-limit, auth, transformation).             | Kong, APISIX, Emissary               |
| **network**       | Транспортный слой: CNI, Service Mesh, DNS, L2/L3.                          | Cilium, Istio, MetalLB               |
| **security**      | Runtime security, supply chain, policy enforcement.                        | Falco, Kyverno, Vault, Trivy         |
| **iam**           | Аутентификация, авторизация, SSO для людей и сервисов.                     | Keycloak, Dex, OAuth2-Proxy          |
| **gitops**        | Расширение ArgoCD: progressive delivery, workflows, events.                | Argo Rollouts, Argo Workflows        |
| **platform**      | Платформенные абстракции: CI/CD, serverless, autoscaling, cloud control.   | Crossplane, Karpenter, Knative       |
| **devtools**      | Инструменты до момента деплоя: репозитории, registry, анализ кода.         | Harbor, GitLab, SonarQube            |
| **observability** | Полный стек наблюдаемости: метрики, логи, трейсы, алертинг.                | Prometheus, Loki, Tempo, Pyroscope   |
| **finops**        | Visibility и управление затратами.                                         | OpenCost                             |
| **backup-dr**     | Защита от потери данных: backup, restore, disaster recovery.               | Velero, Stash                        |
| **chaos**         | Проверка отказоустойчивости через контролируемые эксперименты.             | Chaos Mesh                           |

## k3s на VPS

Рекомендуемый способ развёртывания на VPS - **k3s** с отключённым встроенным Traefik.

```bash
# Установка k3s без встроенного ingress (оставляем порты 80/443 для Istio)
curl -sfL https://get.k3s.io | sh -s - server --disable=traefik

# kubeconfig для текущего пользователя
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(whoami):$(whoami)" ~/.kube/config
chmod 600 ~/.kube/config

echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Проверка
kubectl get nodes
```

На k3s встроен **Klipper Service LB** (`servicelb`). Когда Istio Gateway создаёт Service `type: LoadBalancer`, k3s автоматически назначает IP вашей VPS. **_MetalLB не нужен_**.

```bash
# Проверка
kubectl get svc -n istio-system istio-ingressgateway
# TYPE: LoadBalancer, EXTERNAL-IP: <IP вашей VPS>
```

## Bootstrap-порядок (от нуля до production)

### Этап 0: Подготовка VPS (вне git)

```bash
# Установка k3s без встроенного Traefik
curl -sfL https://get.k3s.io | sh -s - server --disable=traefik

# kubeconfig для Lens/Ansible
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
chmod 600 ~/.kube/config
```

### Этап 1: ArgoCD bootstrap через Ansible

Не используем argocd CLI binary. Весь bootstrap - через `Ansible`.

```bash
# Из корня репозитория
ansible-playbook -i ansible/inv-<ENV> ansible/install-argo.yaml -D
```
