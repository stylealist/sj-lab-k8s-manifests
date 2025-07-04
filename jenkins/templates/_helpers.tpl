{{- define "jenkins.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "jenkins.fullname" -}}
{{ .Release.Name }}
{{- end }}