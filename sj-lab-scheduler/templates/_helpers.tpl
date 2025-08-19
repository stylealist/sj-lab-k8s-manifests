{{/*
Return the full name of the release
*/}}
{{- define "sj-lab-scheduler.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Return the name of the chart
*/}}
{{- define "sj-lab-scheduler.name" -}}
{{- .Chart.Name -}}
{{- end }}
