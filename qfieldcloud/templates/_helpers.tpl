{{/*
Expand the name of the chart.
*/}}
{{- define "qfieldcloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "qfieldcloud.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "qfieldcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qfieldcloud.labels" -}}
helm.sh/chart: {{ include "qfieldcloud.chart" . }}
{{ include "qfieldcloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qfieldcloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qfieldcloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "qfieldcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qfieldcloud.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common Django environment variables (shared across app, worker, migration, cronjob)
*/}}
{{- define "qfieldcloud.djangoEnv" -}}
- name: DEBUG
  value: {{ .Values.django.debug | quote }}
- name: ENVIRONMENT
  value: {{ .Values.django.environment | quote }}
- name: DJANGO_SETTINGS_MODULE
  value: {{ .Values.django.settingsModule | quote }}
- name: DJANGO_ALLOWED_HOSTS
  value: {{ .Values.django.allowedHosts | quote }}
- name: DJANGO_USE_X_FORWARDED_HOST
  value: {{ .Values.django.useXForwardedHost | quote }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: SECRET_KEY
- name: SALT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: SALT_KEY
# PostgreSQL
- name: POSTGRES_HOST
  value: {{ .Values.postgres.host | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgres.port | quote }}
- name: POSTGRES_DB
  value: {{ .Values.postgres.database | quote }}
- name: POSTGRES_DB_TEST
  value: {{ printf "test_%s" .Values.postgres.database | quote }}
- name: POSTGRES_USER
  value: {{ .Values.postgres.username | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: POSTGRES_PASSWORD
- name: POSTGRES_SSLMODE
  value: {{ .Values.postgres.sslmode | quote }}
# Storage (MinIO/S3)
- name: STORAGE_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: STORAGE_ACCESS_KEY_ID
- name: STORAGE_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: STORAGE_SECRET_ACCESS_KEY
- name: STORAGE_BUCKET_NAME
  value: {{ .Values.storage.bucketName | quote }}
- name: STORAGE_REGION_NAME
  value: {{ .Values.storage.regionName | quote }}
- name: STORAGE_ENDPOINT_URL
  value: {{ .Values.storage.endpointUrl | quote }}
- name: STORAGES
  value: |
    {
      "default": {
        "BACKEND": "qfieldcloud.filestorage.backend.QfcS3Boto3Storage",
        "OPTIONS": {
          "access_key": "{{ .Values.storage.accessKey }}",
          "secret_key": "{{ .Values.storage.secretKey }}",
          "bucket_name": "{{ .Values.storage.bucketName }}",
          "region_name": "{{ .Values.storage.regionName }}",
          "endpoint_url": "{{ .Values.storage.endpointUrl }}"
        },
        "QFC_IS_LEGACY": {{ .Values.storage.isLegacy }}
      }
    }
# Email
- name: EMAIL_HOST
  value: {{ .Values.email.host | quote }}
- name: EMAIL_PORT
  value: {{ .Values.email.port | quote }}
- name: EMAIL_USE_TLS
  value: {{ .Values.email.useTls | quote }}
- name: EMAIL_USE_SSL
  value: {{ .Values.email.useSsl | quote }}
- name: EMAIL_HOST_USER
  value: {{ .Values.email.user | quote }}
- name: EMAIL_HOST_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "qfieldcloud.fullname" . }}-secret
      key: EMAIL_HOST_PASSWORD
- name: DEFAULT_FROM_EMAIL
  value: {{ .Values.email.defaultFrom | quote }}
# Sentry
- name: SENTRY_DSN
  value: {{ .Values.sentry.dsn | quote }}
- name: SENTRY_SAMPLE_RATE
  value: {{ .Values.sentry.sampleRate | quote }}
- name: SENTRY_RELEASE
  value: {{ .Values.sentry.release | quote }}
- name: SENTRY_ENVIRONMENT
  value: {{ .Values.django.environment | quote }}
# QFieldCloud specific
- name: QFIELDCLOUD_HOST
  value: {{ .Values.ingress.host | quote }}
- name: QFIELDCLOUD_ADMIN_URI
  value: {{ .Values.django.adminUri | quote }}
- name: QFIELDCLOUD_SUBSCRIPTION_MODEL
  value: {{ .Values.django.subscriptionModel | quote }}
- name: QFIELDCLOUD_ACCOUNT_ADAPTER
  value: {{ .Values.django.accountAdapter | quote }}
- name: QFIELDCLOUD_PASSWORD_LOGIN_IS_ENABLED
  value: {{ .Values.django.passwordLoginEnabled | quote }}
- name: QFIELDCLOUD_AUTH_TOKEN_EXPIRATION_HOURS
  value: {{ .Values.django.authTokenExpirationHours | quote }}
- name: QFIELDCLOUD_USE_I18N
  value: {{ .Values.django.useI18n | quote }}
- name: QFIELDCLOUD_DEFAULT_LANGUAGE
  value: {{ .Values.django.defaultLanguage | quote }}
- name: QFIELDCLOUD_DEFAULT_TIME_ZONE
  value: {{ .Values.django.defaultTimeZone | quote }}
- name: QFIELDCLOUD_WORKER_QFIELDCLOUD_URL
  value: {{ .Values.worker.qfieldcloudUrl | quote }}
- name: QFIELDCLOUD_QGIS_IMAGE_NAME
  value: {{ .Values.image.qgis.repository | quote }}
- name: ACCOUNT_EMAIL_VERIFICATION
  value: {{ .Values.django.accountEmailVerification | quote }}
- name: SOCIALACCOUNT_PROVIDERS
  value: {{ .Values.django.socialaccountProviders | quote }}
- name: CORS_ALLOWED_ORIGINS
  value: {{ .Values.django.corsAllowedOrigins | quote }}
- name: CORS_ALLOW_CREDENTIALS
  value: {{ .Values.django.corsAllowCredentials | quote }}
- name: COMPOSE_PROJECT_NAME
  value: "qfieldcloud"
- name: QFIELDCLOUD_DEFAULT_NETWORK
  value: "qfieldcloud"
# Gunicorn
- name: GUNICORN_TIMEOUT_S
  value: {{ .Values.gunicorn.timeoutS | quote }}
- name: GUNICORN_MAX_REQUESTS
  value: {{ .Values.gunicorn.maxRequests | quote }}
- name: GUNICORN_WORKERS
  value: {{ .Values.gunicorn.workers | quote }}
- name: GUNICORN_THREADS
  value: {{ .Values.gunicorn.threads | quote }}
{{- end }}
