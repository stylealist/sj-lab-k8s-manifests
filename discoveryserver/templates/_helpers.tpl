{{- define "discoveryserver.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "discoveryserver.fullname" -}}
{{ .Release.Name }}
{{- end }}