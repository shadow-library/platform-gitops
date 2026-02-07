{{/*
=============================================================================
Node.js Service Helm Chart - Template Helpers
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "node-service.name" -}}
{{- printf "%s" .Values.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "node-service.fullname" -}}
{{- if contains .Values.name .Release.Name }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Values.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "node-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "node-service.labels" -}}
helm.sh/chart: {{ include "node-service.chart" . }}
{{ include "node-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.name }}
app.kubernetes.io/component: {{ .Values.type }}
shadow-library.io/service: {{ .Values.service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "node-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "node-service.serviceAccountName" -}}
{{- include "node-service.fullname" . }}
{{- end }}

{{/*
Generate the full image name from name and tag.
Registry and organization are sourced from global cluster values.
Image format: <registry>/<organization>/<name>:<tag>
*/}}
{{- define "node-service.image" -}}
{{- printf "%s/%s/%s:%s" .Values.global.registry .Values.global.organization .Values.name .Values.image.tag }}
{{- end }}

{{/*
Determine the application port based on type.
- api:    8080
- web:    3000
- worker: none (no HTTP server)
- stream: 8080
*/}}
{{- define "node-service.appPort" -}}
{{- if eq .Values.type "api" -}}
8080
{{- else if eq .Values.type "web" -}}
3000
{{- else if eq .Values.type "worker" -}}
0
{{- else if eq .Values.type "stream" -}}
8080
{{- else -}}
8080
{{- end -}}
{{- end }}

{{/*
Determine if the app has an HTTP server (excludes workers)
*/}}
{{- define "node-service.hasHttpServer" -}}
{{- if eq .Values.type "worker" -}}
false
{{- else -}}
true
{{- end -}}
{{- end }}

{{/*
Health check port (always 8081)
*/}}
{{- define "node-service.healthPort" -}}
8081
{{- end }}

{{/*
Determine if Vault should be enabled.
Default: enabled for api, worker, stream; disabled for web.
Can be overridden explicitly via vault.enabled in values.
A null value is treated as "not set" and falls through to the type-based default.
*/}}
{{- define "node-service.vaultEnabled" -}}
{{- if and (hasKey .Values "vault") (hasKey .Values.vault "enabled") (not (kindIs "invalid" .Values.vault.enabled)) -}}
  {{- .Values.vault.enabled -}}
{{- else if eq .Values.type "web" -}}
  false
{{- else -}}
  true
{{- end -}}
{{- end }}

{{/*
Determine if ingress should be created.
- Workers never get ingress
- Other types depend on ingress.enabled value
*/}}
{{- define "node-service.ingressEnabled" -}}
{{- if eq .Values.type "worker" -}}
false
{{- else -}}
{{- .Values.ingress.enabled | default true -}}
{{- end -}}
{{- end }}

{{/*
Resource presets based on size.
Returns CPU and memory limits/requests
*/}}
{{- define "node-service.resources" -}}
{{- $size := .Values.size | default "S" | upper }}
{{- if eq $size "XS" }}
limits:
  cpu: 100m
  memory: 128Mi
requests:
  cpu: 50m
  memory: 64Mi
{{- else if eq $size "S" }}
limits:
  cpu: 200m
  memory: 256Mi
requests:
  cpu: 100m
  memory: 128Mi
{{- else if eq $size "M" }}
limits:
  cpu: 500m
  memory: 512Mi
requests:
  cpu: 250m
  memory: 256Mi
{{- else if eq $size "L" }}
limits:
  cpu: 1000m
  memory: 1Gi
requests:
  cpu: 500m
  memory: 512Mi
{{- else if eq $size "XL" }}
limits:
  cpu: 2000m
  memory: 2Gi
requests:
  cpu: 1000m
  memory: 1Gi
{{- else }}
{{/* Default to S if unknown size */}}
limits:
  cpu: 200m
  memory: 256Mi
requests:
  cpu: 100m
  memory: 128Mi
{{- end }}
{{- end }}

{{/*
Generate ingress host from global baseDomain.
Uses service field for the subdomain.
*/}}
{{- define "node-service.ingressHost" -}}
{{- printf "%s.%s" .Values.service .Values.global.baseDomain }}
{{- end }}

{{/*
Generate ingress path based on app type.
- api:    /api
- web:    /
- stream: /ws, /stream
- worker: N/A (no ingress)
*/}}
{{- define "node-service.ingressPath" -}}
{{- if eq .Values.type "api" -}}
/api
{{- else if eq .Values.type "stream" -}}
/ws
{{- else -}}
/
{{- end -}}
{{- end }}

{{/*
Generate ingress path type.
- backend: Prefix (matches /api/*)
- frontend: Prefix (matches everything else)
*/}}
{{- define "node-service.ingressPathType" -}}
Prefix
{{- end }}

{{/*
Vault secrets mount path for keys/files
*/}}
{{- define "node-service.vaultSecretsPath" -}}
/etc/secrets
{{- end }}

{{/*
Vault KV path for app-specific secrets
Format: <environment>/apps/<app-name>
*/}}
{{- define "node-service.vaultAppPath" -}}
{{- printf "%s/apps/%s" .Values.global.environment .Values.name }}
{{- end }}

{{/*
Vault KV path for common config
Format: <environment>/common/config
*/}}
{{- define "node-service.vaultCommonConfigPath" -}}
{{- printf "%s/common/config" .Values.global.environment }}
{{- end }}

{{/*
Vault KV path for common keys (certificates, jwt, encryption keys)
Format: <environment>/common/keys
*/}}
{{- define "node-service.vaultCommonKeysPath" -}}
{{- printf "%s/common/keys" .Values.global.environment }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "node-service.configMapName" -}}
{{- include "node-service.fullname" . }}-config
{{- end }}

{{/*
Generate pod annotations for Vault sidecar
Vault paths:
  - App secrets: <environment>/apps/<app-name>
  - Common config: <environment>/common/config
  - Common keys: <environment>/common/keys (all files auto-imported)
*/}}
{{- define "node-service.vaultAnnotations" -}}
{{- if eq (include "node-service.vaultEnabled" .) "true" }}
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/agent-inject-status: "update"
vault.hashicorp.com/role: {{ include "node-service.fullname" . | quote }}
vault.hashicorp.com/agent-pre-populate-only: "false"
vault.hashicorp.com/agent-init-first: "true"
vault.hashicorp.com/agent-inject-secret-app: {{ include "node-service.vaultAppPath" . | quote }}
vault.hashicorp.com/agent-inject-secret-common-config: {{ include "node-service.vaultCommonConfigPath" . | quote }}
vault.hashicorp.com/agent-inject-secret-common-keys: {{ include "node-service.vaultCommonKeysPath" . | quote }}
vault.hashicorp.com/agent-inject-file-common-keys: {{ include "node-service.vaultSecretsPath" . | quote }}
{{- end }}
{{- end }}

