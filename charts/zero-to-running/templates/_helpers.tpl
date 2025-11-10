{{/*
Expand the name of the chart.
*/}}
{{- define "zero-to-running.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zero-to-running.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "zero-to-running.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zero-to-running.labels" -}}
helm.sh/chart: {{ include "zero-to-running.chart" . }}
{{ include "zero-to-running.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zero-to-running.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zero-to-running.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service labels for specific service
*/}}
{{- define "zero-to-running.serviceLabels" -}}
app: {{ .serviceName }}
{{ include "zero-to-running.labels" . }}
{{- end }}

{{/*
Service selector for specific service
*/}}
{{- define "zero-to-running.serviceSelector" -}}
app: {{ .serviceName }}
{{- end }}

