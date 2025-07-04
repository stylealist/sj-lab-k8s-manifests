{{/*
Return the full name of the release
*/}}
{{- define "mapservice-rest.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Return the name of the chart
*/}}
{{- define "mapservice-rest.name" -}}
{{- .Chart.Name -}}
{{- end }}
