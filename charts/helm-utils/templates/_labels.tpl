{{/* Common labels */}}
{{- define "helm-utils.labels" -}}
helm.sh/chart: {{ include "helm-utils.chart" . }}
{{ include "helm-utils.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "helm-utils.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm-utils.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
