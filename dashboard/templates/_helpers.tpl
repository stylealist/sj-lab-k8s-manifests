{{- define "apigateway.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "apigateway.fullname" -}}
{{ .Release.Name }}
{{- end }}
