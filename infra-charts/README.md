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
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

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

Устанавливаем `k3s`, `kubectl`, `Ansible` и зависимости на управляющую ноду.

#### Установка k3s

```bash
# Установка k3s без встроенного Traefik
curl -sfL https://get.k3s.io | sh -s - server --disable=traefik

# kubeconfig для текущего пользователя
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(whoami):$(whoami)" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

#### Установка Ansible и модулей

```bash
# Создаём и активируем окружение
python3 -m venv venv
. venv/bin/activate

# Устанавливаем Ansible
pip install -r venv/requirements.txt

# Проверка установки
ansible --version

# Устанавливаем модули
ansible-galaxy collection install -r requirements.yml

# Деактивируем окружение
deactivate
```

#### Установка Age

```bash
# Скачиваем последний релиз (проверь актуальную версию на https://github.com/getsops/sops/releases)
cd /tmp
curl -Lo age.tar.gz "https://github.com/FiloSottile/age/releases/download/v1.3.1/age-v1.3.1-linux-amd64.tar.gz"
tar -xzf age.tar.gz

sudo mv age/age /usr/local/bin/
sudo mv age/age-keygen /usr/local/bin/

# Проверка установки
age --version
age-keygen --version
```

#### Установка Sops

```bash
# Скачиваем последний релиз (проверь актуальную версию на https://github.com/getsops/sops/releases)
cd /tmp
curl -Lo sops "https://github.com/getsops/sops/releases/download/v3.13.1/sops-v3.13.1.linux.amd64"
chmod +x sops

sudo mv sops /usr/local/bin/

# Проверка
sops --version
```

Настройка age-ключа для Sops

```bash
# Создаём директорию для ключей
mkdir -p ~/.config/sops/age

# Генерируем ключ (приватный + публичный)
age-keygen -o ~/.config/sops/age/keys.txt
```

Вывод будет примерно таким:

```plaintext
Public key: age1ql3z7yy3k5fww0c7c9r8v2s7t9u0v1w2x3y4z5...
```

Шифрование и расшифровка файлов:

```bash
# Зашифровать файл
sops -e -i infra-charts/core/argocd/values.secrets.yaml

# Расшифровать для просмотра
sops -d infra-charts/core/argocd/values.secrets.yaml

# Редактировать зашифрованный файл (sops автоматически расшифрует и зашифрует при сохранении)
sops infra-charts/core/argocd/values.secrets.yaml
```

Шифруем приватный age-ключ через `Ansible Vault`

```bash
ansible-vault encrypt_string 'AGE-SECRET-KEY-1QZ2HFAJ...' --name 'sops_age_key'
```

Вывод будет таким:

```plaintext
sops_age_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  34616535353761303066343232306663666132386237653963353531326237643431323765303330
  3930343235363261633132393364653433383239626334660a626436356131616435666331323634
  65346361316536306635366430383836363563643164316333326635306534653561316136636338
  6438386232313234650a383638393937636534626564613133363730636232383066313339643538
  35386431333832303638643139623838323962653934613237373962643664303965306666633561
  66663231336234663532636266396533333237336164373039383663666437313361623330663262
  32306232363161346335356661393964343737303931626162376336383038316133633239663165
  36363961343566663563
```

Вставляем в inventory (`ansible/inv-<ENV>.yaml`):

```yaml
all:
  children:
    initial-host:
      hosts:
        localhost:
          ansible_connection: local
          stage_values_file: values.test.yaml
          sops_age_key: !vault |
            $ANSIBLE_VAULT;1.1;AES256
            34616535353761303066343232306663666132386237653963353531326237643431323765303330
            3930343235363261633132393364653433383239626334660a626436356131616435666331323634
            65346361316536306635366430383836363563643164316333326635306534653561316136636338
            6438386232313234650a383638393937636534626564613133363730636232383066313339643538
            35386431333832303638643139623838323962653934613237373962643664303965306666633561
            66663231336234663532636266396533333237336164373039383663666437313361623330663262
            32306232363161346335356661393964343737303931626162376336383038316133633239663165
            36363961343566663563
```

#### Создаём и активируем venv

```bash
cd ~/infra-charts/ansible

# Создаём окружение
python3 -m venv ~/ansible-venv

# Активируем
. ~/ansible-venv/bin/activate

# Проверь, что venv активировался
which python3

# Проверяем, что pip из venv
which pip
```

### Этап 1: ArgoCD bootstrap через Ansible

Не используем argocd CLI binary. Весь bootstrap - через `Ansible`.

```bash
# Из корня репозитория
ansible-playbook -i ansible/inv-<ENV> ansible/install-argo.yaml -D
```
