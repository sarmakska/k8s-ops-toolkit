# Helm chart reference

The `charts/nextjs-app` chart is opinionated: it deploys exactly what most
Next.js apps need on Kubernetes and exposes the knobs you actually turn. The
values below match `charts/nextjs-app/values.yaml` exactly.

## Minimal install

```bash
helm install my-app charts/nextjs-app \
  --set image.repository=ghcr.io/you/my-app \
  --set image.tag=v1.0.0 \
  --set ingress.host=app.example.com
```

## Values

```yaml
replicas: 2

image:
  repository: ghcr.io/you/my-app
  tag: v1.0.0
  pullPolicy: IfNotPresent
  pullSecrets:
    - ghcr-creds          # names of existing image pull secrets

rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0

service:
  port: 3000              # container port; the Service publishes :80

ingress:
  enabled: true
  className: nginx
  host: app.example.com
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 32m
  tls:
    enabled: true
    issuer: letsencrypt-prod   # ClusterIssuer name

resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 1000m, memory: 1Gi }

autoscaling:
  enabled: true
  min: 2
  max: 10
  targetCPU: 70

pdb:
  enabled: true
  minAvailable: 1

scheduling:
  spread:
    enabled: true                 # set false on single-node clusters
    whenUnsatisfiable: ScheduleAnyway   # or DoNotSchedule for hard isolation
    topologyKeys:
      - topology.kubernetes.io/zone
      - kubernetes.io/hostname
  nodeSelector: {}                # passed through verbatim when set
  affinity: {}
  tolerations: []

terminationGracePeriodSeconds: 30 # drain window before SIGKILL

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]

probes:
  liveness:
    path: /api/health
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    path: /api/health
    initialDelaySeconds: 5
    periodSeconds: 5

env:
  - name: NODE_ENV
    value: production
secretEnv:
  - name: DATABASE_URL
    secretName: my-app-secrets
    key: database-url
envFromSecret:
  - my-app-runtime        # whole Secrets mounted as env via envFrom

monitoring:
  enabled: true
  prometheusServiceMonitor: true
  metricsPath: /api/metrics
  metricsPort: 3000
  interval: 30s
  serviceMonitorLabels:
    release: monitoring   # match your kube-prometheus-stack release label
```

## What each template does

| Template | Renders | Why |
| --- | --- | --- |
| `deployment.yaml` | The app | Rolling update strategy, readiness and liveness probes on `/api/health`, hardened pod and container security context, zone-aware topology spread with optional nodeSelector, affinity and tolerations, a configurable graceful-shutdown window, three env injection patterns |
| `service.yaml` | ClusterIP | Publishes port 80 and targets the container port (3000 by default) |
| `ingress.yaml` | nginx Ingress | TLS via cert-manager, host routing, extra annotations |
| `hpa.yaml` | HorizontalPodAutoscaler | Optional, CPU based |
| `pdb.yaml` | PodDisruptionBudget | Optional, keeps a floor of available replicas during drains |
| `servicemonitor.yaml` | ServiceMonitor | Prometheus scrape config; needs kube-prometheus-stack CRDs |

## Health check

The chart expects a `/api/health` endpoint returning 200 OK. Next.js apps on
the `app/` router can drop this in a one-liner:

```typescript
// app/api/health/route.ts
export async function GET() {
  return Response.json({ ok: true })
}
```

Override the path with `--set probes.liveness.path=/healthz --set probes.readiness.path=/healthz` if you have a different convention.

## Metrics

If you want Prometheus to scrape the app:

1. Expose `/api/metrics` returning Prometheus text format. For Next.js,
   [`prom-client`](https://www.npmjs.com/package/prom-client) is the standard option.
2. Keep `monitoring.enabled` and `monitoring.prometheusServiceMonitor` true.
3. Set `monitoring.serviceMonitorLabels.release` to your kube-prometheus-stack
   release name so the operator selects the ServiceMonitor.

The bundled Grafana "Next.js app" dashboard expects standard counters:
`http_requests_total`, `http_request_duration_seconds_bucket`, plus the default
Node.js process metrics.

## Scheduling and resilience

By default the chart spreads a release's pods across failure domains so a PDB
that promises `minAvailable` replicas can actually be honoured. Each
configured topology key becomes one `topologySpreadConstraint` with `maxSkew:
1` and a label selector scoped to this release, widest blast radius first:
zone, then host.

```yaml
scheduling:
  spread:
    enabled: true
    whenUnsatisfiable: ScheduleAnyway
    topologyKeys:
      - topology.kubernetes.io/zone
      - kubernetes.io/hostname
```

`ScheduleAnyway` is the safe default: when a zone is full the scheduler still
places the pod rather than leaving it `Pending`. Switch to `DoNotSchedule` when
you want hard isolation and would rather a pod wait than co-locate. On a
single-node cluster (kind, minikube) set `scheduling.spread.enabled: false`,
since the host-level constraint can never be satisfied.

`scheduling.nodeSelector`, `scheduling.affinity`, and `scheduling.tolerations`
are passed through verbatim and omitted entirely when left empty, so you can
pin the app to a dedicated node pool without templating your own manifests:

```bash
helm install my-app charts/nextjs-app \
  --set 'scheduling.nodeSelector.pool=web' \
  --set 'scheduling.tolerations[0].key=dedicated' \
  --set 'scheduling.tolerations[0].operator=Equal' \
  --set 'scheduling.tolerations[0].value=web' \
  --set 'scheduling.tolerations[0].effect=NoSchedule'
```

`terminationGracePeriodSeconds` (default 30) is the window the kubelet gives
the pod to drain in-flight requests before sending SIGKILL on a rollout.

## Secrets

Three patterns are supported:

- `env:` inlines non-secret values into the Deployment.
- `secretEnv:` maps individual Secret keys to environment variables.
- `envFromSecret:` mounts whole Secrets as environment variables via `envFrom`.

Create Secrets separately with `kubectl create secret generic ...` or via your
secret manager of choice (External Secrets Operator, sealed-secrets). The chart
does not own secret lifecycle.
