# Helm chart reference

The `charts/nextjs-app` chart is opinionated: it deploys exactly what
most Next.js apps need on Kubernetes and exposes the knobs you actually
turn.

## Minimal install

```bash
helm install my-app charts/nextjs-app \
  --set image.repository=ghcr.io/you/my-app \
  --set image.tag=v1.0.0 \
  --set ingress.host=app.example.com
```

## Common values

```yaml
image:
  repository: ghcr.io/you/my-app
  tag: v1.0.0
  pullPolicy: IfNotPresent
  pullSecrets: [ghcr-creds]

replicaCount: 2

resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 1000m, memory: 1Gi }

env:
  NODE_ENV: production
  DATABASE_URL: postgres://... # prefer envFromSecret

envFromSecret:
  - my-app-secrets

ingress:
  host: app.example.com
  className: nginx
  tls:
    enabled: true
    issuer: letsencrypt-prod   # ClusterIssuer name
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 32m

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 12
  targetCPUUtilizationPercentage: 70

pdb:
  enabled: true
  minAvailable: 1

serviceMonitor:
  enabled: true     # Prometheus picks up /api/metrics
  path: /api/metrics
  interval: 30s
```

## What each template does

| Template | Renders | Why |
| --- | --- | --- |
| `deployment.yaml` | The app | Rolling updates, readiness probe on `/api/health`, security context |
| `service.yaml` | ClusterIP | Targets the deployment on port 3000 by default |
| `ingress.yaml` | nginx Ingress | TLS via cert-manager, host-based routing |
| `hpa.yaml` | HorizontalPodAutoscaler | Optional, CPU-based by default; metrics-based optional |
| `pdb.yaml` | PodDisruptionBudget | Optional, prevents simultaneous evictions |
| `servicemonitor.yaml` | ServiceMonitor | Prometheus scrape config; needs kube-prometheus-stack CRDs |

## Health check

The chart expects a `/api/health` endpoint returning 200 OK. Next.js
apps using the `app/` router can drop this in a one-liner:

```typescript
// app/api/health/route.ts
export async function GET() {
  return Response.json({ ok: true })
}
```

Override the path with `--set probe.path=/health` if you have a
different convention.

## Metrics

If you want Prometheus to scrape the app:

1. Expose `/api/metrics` returning Prometheus text format.
   For Next.js, [`prom-client`](https://www.npmjs.com/package/prom-client) is the standard option.
2. Set `serviceMonitor.enabled=true` in values.

The pre-baked Grafana "Next.js app" dashboard expects standard
counters: `http_requests_total`, `http_request_duration_seconds`, plus
the default Node.js process metrics.

## Secrets

Two patterns supported:

- `env:` — values inlined into the deployment (only for non-secret values).
- `envFromSecret: [secret-name]` — the chart sets `envFrom: secretRef`.

Create the secret separately with `kubectl create secret generic ...`
or via your secret manager of choice (External Secrets Operator,
sealed-secrets, etc.). The chart does not own secret lifecycle.
