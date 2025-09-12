{{- define "securekit.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end }}

{{- define "securekit.podSecurityContext" -}}
{{- toYaml .Values.securekit.podSecurityContext | nindent 0 -}}
{{- end }}

{{- define "securekit.containerSecurityContext" -}}
{{- toYaml .Values.securekit.containerSecurityContext | nindent 0 -}}
{{- end }}

{{- define "securekit.probes.http" -}}
livenessProbe:
  httpGet:
    path: {{ .Values.securekit.probes.http.path }}
    port: {{ .Values.securekit.probes.http.port }}
  initialDelaySeconds: {{ .Values.securekit.probes.http.initialDelaySeconds }}
  periodSeconds: {{ .Values.securekit.probes.http.periodSeconds }}
readinessProbe:
  httpGet:
    path: {{ .Values.securekit.probes.http.path }}
    port: {{ .Values.securekit.probes.http.port }}
  initialDelaySeconds: {{ .Values.securekit.probes.http.initialDelaySeconds }}
  periodSeconds: {{ .Values.securekit.probes.http.periodSeconds }}
{{- end }}
