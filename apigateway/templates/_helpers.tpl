{{- define "apigateway.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "apigateway.fullname" -}}
{{ include "apigateway.name" . }}-{{ .Release.Name }}
{{- end }}
