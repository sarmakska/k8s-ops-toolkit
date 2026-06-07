{{/*
Common labels applied to every object the chart renders.
*/}}
{{- define "nextjs-app.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: k8s-ops-toolkit
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels. These must stay stable across upgrades, so they are a
strict subset of the common labels and never include version data.
*/}}
{{- define "nextjs-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Topology spread constraints. One constraint per configured topology key,
each spreading this release's own pods (matched on the selector labels) as
evenly as possible. maxSkew is fixed at 1 so the scheduler keeps replicas
balanced across the failure domain.
*/}}
{{- define "nextjs-app.topologySpread" -}}
{{- range .Values.scheduling.spread.topologyKeys }}
- maxSkew: 1
  topologyKey: {{ . }}
  whenUnsatisfiable: {{ $.Values.scheduling.spread.whenUnsatisfiable }}
  labelSelector:
    matchLabels:
      {{- include "nextjs-app.selectorLabels" $ | nindent 6 }}
{{- end }}
{{- end -}}
