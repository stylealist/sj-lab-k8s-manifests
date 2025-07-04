{{/*
Expand the name of the chart.
*/}}
{{- define "argocd.fullname" -}}
{{- printf "%s" .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
