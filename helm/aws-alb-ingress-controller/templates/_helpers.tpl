{{/*
Expand the name of the chart.
*/}}
{{- define "aws-alb-ingress-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "aws-alb-ingress-controller.fullname" -}}
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
{{- define "aws-alb-ingress-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "aws-alb-ingress-controller.labels" -}}
helm.sh/chart: {{ include "aws-alb-ingress-controller.chart" . }}
{{ include "aws-alb-ingress-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "aws-alb-ingress-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aws-alb-ingress-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "aws-alb-ingress-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "aws-alb-ingress-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get cluster name - fallback to .Values.aws.clusterName or derive from Helm release
*/}}
{{- define "aws-alb-ingress-controller.clusterName" -}}
{{- if .Values.clusterName }}
{{- .Values.clusterName }}
{{- else }}
{{- .Release.Name }}-cluster
{{- end }}
{{- end }}
