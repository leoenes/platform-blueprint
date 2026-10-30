{{/* true when the tool is not in the cluster's disabledTools list */}}
{{- define "platform.enabled" -}}
{{- $name := index . 0 -}}{{- $values := index . 1 -}}
{{- if not (has $name ($values.disabledTools | default list)) }}true{{ end -}}
{{- end -}}

{{/* common Application skeleton fields */}}
{{- define "platform.appMeta" -}}
namespace: argocd
finalizers: [resources-finalizer.argocd.argoproj.io]
labels:
  platform.acme.io/cluster: {{ .Values.global.clusterName | quote }}
{{- end -}}
