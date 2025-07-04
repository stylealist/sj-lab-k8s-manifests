{{- define "sj-lab-webserver.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "sj-lab-webserver.fullname" -}}
{{ .Release.Name }}
{{- end }}