# Argo CD

Wrapper Helm chart для установки Argo CD

## Состав

- `Chart.yaml` - dependency на upstream chart `argo-cd` (версия `9.5.6`)
- `values.common.yaml` - общие настройки
- `values.test.yaml`, `values.prod.yaml` - env-override

## Установка

Устанавливается через `ansible/install-argo.yaml`

Ручной вариант:

```bash
helm dep update infra-charts/argocd
helm upgrade --install argocd -n argocd infra/argocd \
  --create-namespace \
  -f infra-charts/argocd/values.common.yaml
  -f infra-charts/argocd/values.<env>.yaml
```

## Особенности

- В `argo-cd.cm.helm.valuesFileSchemes` включены схемы `secrets://` и `secrets+age-import://`.

## Проверка

```bash
helm lint infra-charts/argocd --strict
kubectl -n argocd get deploy,statefulset,pods
```
