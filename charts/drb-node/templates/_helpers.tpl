{{/*
Expand the name of the chart.
*/}}
{{- define "drb-node.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "drb-node.fullname" -}}
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
{{- define "drb-node.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "drb-node.labels" -}}
helm.sh/chart: {{ include "drb-node.chart" . }}
{{ include "drb-node.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "drb-node.selectorLabels" -}}
app.kubernetes.io/name: {{ include "drb-node.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "drb-node.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "drb-node.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate node container spec
*/}}
{{- define "drb-node.container" -}}
- name: drb-node
  image: {{ .image.repository }}:{{ .image.tag }}
  imagePullPolicy: {{ .image.pullPolicy }}
  ports:
    - name: http
      containerPort: {{ .port }}
      protocol: TCP
  env:
    {{- range $key, $value := .env }}
    - name: {{ $key }}
      value: {{ $value | quote }}
    {{- end }}
    {{- if .extraEnv }}
    {{- range .extraEnv }}
    - name: {{ .name }}
      value: {{ .value | quote }}
    {{- end }}
    {{- end }}
  volumeMounts:
    - name: app-config
      mountPath: "/app/.env"
      subPath: .env
      readOnly: true
    {{- if .privateKeySecret.enabled }}
    - name: private-key
      mountPath: "/app/static-key"
      readOnly: true
    {{- else if .persistence.enabled }}
    - name: static-key
      mountPath: "/app/static-key"
      {{- if .persistence.subPath }}
      subPath: {{ .persistence.subPath }}
      {{- end }}
    {{- end }}
  {{- if .resources }}
  resources:
    {{- toYaml .resources | nindent 4 }}
  {{- end }}
  {{- if .healthcheck.enabled }}
  livenessProbe:
    exec:
      command:
        - sh
        - -c
        - "nc -z localhost {{ .port }} || exit 1"
    initialDelaySeconds: {{ .healthcheck.startPeriod | replace "s" "" | int }}
    periodSeconds: {{ .healthcheck.interval | replace "s" "" | int }}
    timeoutSeconds: {{ .healthcheck.timeout | replace "s" "" | int }}
    failureThreshold: {{ .healthcheck.retries }}
  readinessProbe:
    exec:
      command:
        - sh
        - -c
        - "nc -z localhost {{ .port }} || exit 1"
    initialDelaySeconds: {{ .healthcheck.startPeriod | replace "s" "" | int }}
    periodSeconds: {{ .healthcheck.interval | replace "s" "" | int }}
    timeoutSeconds: {{ .healthcheck.timeout | replace "s" "" | int }}
    failureThreshold: {{ .healthcheck.retries }}
  {{- end }}
{{- end }}

{{/*
Generate volumes spec
*/}}
{{- define "drb-node.volumes" -}}
- name: app-config
  configMap:
    defaultMode: 0644
    items:
      - key: .env
        path: .env
    name: {{ .configMapName }}
{{- if .privateKeySecret.enabled }}
- name: private-key
  secret:
    secretName: {{ .privateKeySecret.secretName }}
    defaultMode: 0600
{{- else if .persistence.enabled }}
- name: static-key
  persistentVolumeClaim:
    {{- if .persistence.existingClaim }}
    claimName: {{ .persistence.existingClaim }}
    {{- else }}
    claimName: {{ .pvcName }}
    {{- end }}
{{- end }}
{{- if and .staticKeySecret .staticKeySecret.enabled }}
- name: secret-static-key
  secret:
    secretName: {{ .staticKeySecret.secretName }}
    defaultMode: 0600
{{- end }}
{{- end }}

{{/*
Generate init container for waiting on leader
*/}}
{{- define "drb-node.waitForLeader" -}}
- name: wait-for-leader
  image: busybox:1.35
  command:
    - sh
    - -c
    - |
      until nc -z {{ .leaderService }} {{ .leaderPort }}; do
        echo "Waiting for leader node..."
        sleep 2
      done
{{- end }}

{{/*
Generate init container for copying leadernode.bin from Secret to PVC
*/}}
{{- define "drb-node.copyStaticKey" -}}
- name: copy-static-key
  image: busybox:1.35
  command:
    - sh
    - -c
    - |
      if [ -f /secret/{{ .key }} ]; then
        echo "Copying {{ .key }} to PVC..."
        cp /secret/{{ .key }} /static-key/{{ .key }}
        chmod 0600 /static-key/{{ .key }}
        echo "Successfully copied {{ .key }}"
      else
        echo "Error: {{ .key }} not found in Secret"
        exit 1
      fi
  volumeMounts:
    - name: secret-static-key
      mountPath: /secret
      readOnly: true
    - name: static-key
      mountPath: /static-key
{{- end }}
