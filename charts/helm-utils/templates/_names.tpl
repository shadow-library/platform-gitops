{{/*
Common naming helpers
All helpers are namespaced to avoid collisions.
*/}}

{{/*
Return the chart name.
*/}}
{{- define "helm-utils.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "helm-utils.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
