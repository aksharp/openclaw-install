{{/*
Common labels
*/}}
{{- define "openclaw.labels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Chart name
*/}}
{{- define "openclaw.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name (release-name-chartname)
*/}}
{{- define "openclaw.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Gateway full name
*/}}
{{- define "openclaw.gateway.fullname" -}}
{{- include "openclaw.fullname" . }}-gateway
{{- end }}

{{/*
Vault full name
*/}}
{{- define "openclaw.vault.fullname" -}}
{{- include "openclaw.fullname" . }}-vault
{{- end }}

{{/*
OTel Collector full name
*/}}
{{- define "openclaw.otel.fullname" -}}
{{- include "openclaw.fullname" . }}-otel-collector
{{- end }}

{{/*
Prometheus full name
*/}}
{{- define "openclaw.prometheus.fullname" -}}
{{- include "openclaw.fullname" . }}-prometheus
{{- end }}

{{/*
Grafana full name
*/}}
{{- define "openclaw.grafana.fullname" -}}
{{- include "openclaw.fullname" . }}-grafana
{{- end }}

{{/*
Loki full name
*/}}
{{- define "openclaw.loki.fullname" -}}
{{- include "openclaw.fullname" . }}-loki
{{- end }}

{{/*
Alertmanager full name
*/}}
{{- define "openclaw.alertmanager.fullname" -}}
{{- include "openclaw.fullname" . }}-alertmanager
{{- end }}

{{/*
Namespace
*/}}
{{- define "openclaw.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | quote }}
{{- end }}
