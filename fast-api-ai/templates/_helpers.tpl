{{/*
Return the full name of the release
*/}}
{{- define "fast-api-ai.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Return the name of the chart
*/}}
{{- define "fast-api-ai.name" -}}
{{- .Chart.Name -}}
{{- end }}