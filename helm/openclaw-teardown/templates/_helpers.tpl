{{/*
Teardown chart labels
*/}}
{{- define "openclaw-teardown.labels" -}}
app.kubernetes.io/name: {{ include "openclaw-teardown.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "openclaw-teardown.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
