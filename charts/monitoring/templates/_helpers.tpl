{{/*
Expand the name of the chart.
*/}}
{{- define "monitoring.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "monitoring.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "monitoring.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for Thanos Stack monitoring
*/}}
{{- define "monitoring.labels" -}}
helm.sh/chart: {{ include "monitoring.chart" . }}
{{ include "monitoring.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: thanos-stack
{{- if .Values.thanosStack.chainName }}
chain: {{ .Values.thanosStack.chainName }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "monitoring.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "monitoring.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "monitoring.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Thanos Stack namespace helper
*/}}
{{- define "monitoring.thanosNamespace" -}}
{{- .Values.thanosStack.namespace | default "monitoring" }}
{{- end }}

{{/*
Generate Thanos Stack service name with trh-sdk format
*/}}
{{- define "monitoring.thanosStackServiceName" -}}
{{- $serviceName := . -}}
{{- $ctx := $.context -}}
{{- if and $ctx.Values.thanosStack.releaseName $ctx.Values.thanosStack.namespace }}
{{- printf "%s-thanos-stack-%s" $ctx.Values.thanosStack.releaseName $serviceName }}
{{- else }}
{{- printf "%s-svc.%s" $serviceName (include "monitoring.thanosNamespace" $ctx) }}
{{- end }}
{{- end }}

{{/*
Generate service target based on trh-sdk format
*/}}
{{- define "monitoring.serviceTarget" -}}
{{- $serviceName := .serviceName -}}
{{- $port := .port -}}
{{- $ctx := .context -}}
{{- if and $ctx.Values.thanosStack.releaseName $ctx.Values.thanosStack.namespace }}
{{- printf "%s-thanos-stack-%s:%s" $ctx.Values.thanosStack.releaseName $serviceName $port }}
{{- else }}
{{- printf "%s-svc.%s:%s" $serviceName (include "monitoring.thanosNamespace" $ctx) $port }}
{{- end }}
{{- end }}

{{/*
Generate monitoring namespace (either from trh-sdk or default)
*/}}
{{- define "monitoring.namespace" -}}
{{- if .Values.thanosStack.namespace }}
{{- .Values.thanosStack.namespace }}
{{- else }}
{{- "monitoring" }}
{{- end }}
{{- end }}

{{/*
Check if trh-sdk integration is enabled
*/}}
{{- define "monitoring.isTrhSdkEnabled" -}}
{{- if and .Values.thanosStack.releaseName .Values.thanosStack.namespace .Values.global.l1RpcUrl }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}