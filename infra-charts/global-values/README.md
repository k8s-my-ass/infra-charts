# global-values

Глобальные значения и константы платформы, которые используются множеством чартов.

## Принцип

- Здесь хранятся **cross-cutting concerns**: домены, storage classes, метки, лимиты
- Чарты ссылаются на эти значения через `global:` секцию в `values.common.yaml` или через ArgoCD ApplicationSet
- Не храните здесь секреты - используйте `security/external-secrets` или `security/sealed-secrets`

## Структура

| Файл                   | Назначение                                                           |
| ---------------------- | -------------------------------------------------------------------- |
| `common.yaml`          | Общие метки, tolerations, affinity, service account defaults         |
| `domains.yaml`         | Все ingress-домены по окружениям (test, staging, prod)               |
| `storage-classes.yaml` | Маппинг StorageClass по окружениям и типам (fast, standard, archive) |
| `network-policy.yaml`  | Базовые CIDR, namespace labels для network policies                  |
| `alerting.yaml`        | Глобальные endpoints для алертинга (Slack, PagerDuty, email)         |

## Использование в чартах

В `values.common.yaml` чарта:

```yaml
global:
  domain: "{{ .Values.global.domains.app }}"
  storageClass: "{{ .Values.global.storage.standard }}"
```

В ArgoCD ApplicationSet значения мерджатся через valueFiles:

```yaml
valueFiles:
  - global-values/common.yaml
  - values.common.yaml
  - values.test.yaml
```
