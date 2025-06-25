{{/*
Chart 이름 반환
*/}}
{{- define "sj-lab-webserver.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Chart 전체 이름 반환 (release-name + chart-name)
*/}}
{{- define "sj-lab-webserver.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
