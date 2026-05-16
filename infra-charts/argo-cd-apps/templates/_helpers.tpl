{{/*
Common labels
*/}}
{{- define "argo-cd-apps.labels" -}}
helm.sh/chart: {{ include "argo-cd-apps.chart" . }}
app.kubernetes.io/name: {{ include "argo-cd-apps.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Chart name
*/}}
{{- define "argo-cd-apps.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name
*/}}
{{- define "argo-cd-apps.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
