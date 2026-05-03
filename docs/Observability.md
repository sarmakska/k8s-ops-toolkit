# Observability

The toolkit installs the three things you need before you go live:
metrics, logs, and alerts. The fourth — distributed tracing — is
deliberately not bundled.

## Stack

| Layer | Tool | Why this one |
| --- | --- | --- |
| Metrics scrape | Prometheus | The default. Everything speaks Prometheus. |
| Metrics dashboards | Grafana | The default. Nothing is faster to point at Prometheus. |
| Alert routing | Alertmanager | Comes free with kube-prometheus-stack. |
| Log aggregation | Loki | Pairs with Grafana. Cheaper than ELK at SME scale. |
| Log shipping | Promtail | Loki's official agent. Zero config in most clusters. |

## Pre-baked dashboards

Located in `manifests/grafana-dashboards/`:

- **Cluster Overview** — node CPU, memory, disk; pod restarts; image pull errors.
- **Ingress nginx** — RPS, p50/p95/p99 latency, status code distribution, top hosts.
- **Next.js app** — HTTP request rate, error rate, p95 latency, Node.js heap usage, event loop lag.

Add your own by dropping JSON into `manifests/grafana-dashboards/` and
applying. The Grafana sidecar picks them up automatically.

## Pre-baked alerts

In `manifests/prometheus-rules/`:

- `KubePodCrashLooping` — pod restart count > 5 in 10 minutes.
- `KubePersistentVolumeFillingUp` — predicted full within 6 hours.
- `IngressNginxHigh5xxRate` — > 5% 5xx for 5 minutes.
- `IngressNginxHighLatency` — p99 > 2s for 5 minutes.
- `CertManagerCertificateExpirySoon` — cert expires in less than 14 days.
- `NodeMemoryPressure`, `NodeDiskPressure`, `NodeNotReady` — kube-prometheus defaults.

Configure receivers (Slack, PagerDuty, email) in `values-alertmanager.yaml`:

```yaml
alertmanager:
  config:
    receivers:
      - name: ops-slack
        slack_configs:
          - api_url: '<your-webhook>'
            channel: '#ops-alerts'
    route:
      receiver: ops-slack
      group_by: [alertname, namespace]
```

## Log queries

Grafana → Explore → Loki:

```logql
{namespace="default", app="my-app"} |= "error"
```

```logql
sum by (status) (rate({app="my-app"}[5m]))
```

Indexed labels are kept small (namespace, app, pod). Everything else is
in the log line — Loki is cheap exactly because it does not index every
field.

## What is intentionally missing

- **Distributed tracing**. Add Tempo + OpenTelemetry if you need it. The
  pattern: deploy Tempo via the kube-prometheus-stack ecosystem chart,
  have your app emit OTLP traces, point Grafana at Tempo as a
  datasource. Two days of work, not five. We do not bundle it because
  90 percent of Next.js production deployments do not need it.
- **Long-term metric storage**. Prometheus stores 15 days by default.
  For longer retention, point at Mimir or Cortex.
- **APM (DataDog, New Relic, etc.)**. Pick if you are already paying
  for one. Not bundled here.

## Total cost

Self-hosted on a 3-node cluster at DigitalOcean prices:

- Cluster: ~$36/month (3x s-2vcpu-4gb)
- Persistent disks for Prometheus + Loki: ~$20/month
- LoadBalancer for ingress: $12/month

Total: roughly $70/month for the platform stack, hosting an unlimited
number of apps.
