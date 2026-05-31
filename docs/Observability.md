# Observability

The toolkit installs the things you need before you go live: metrics, logs,
alerts, and spend tracking. Distributed tracing is deliberately not bundled.

## Stack

| Layer | Tool | Why this one |
| --- | --- | --- |
| Metrics scrape | Prometheus | The default. Everything speaks Prometheus. |
| Metrics dashboards | Grafana | Nothing is faster to point at Prometheus. |
| Alert routing | Alertmanager | Comes free with kube-prometheus-stack. |
| Log aggregation | Loki 3.x | Pairs with Grafana. Cheaper than ELK at SME scale. |
| Log shipping | Promtail | Loki's agent. Ships container stdout with near-zero config. |
| Cost | OpenCost | CNCF spend allocation, queryable in Grafana. |

## Bundled dashboards

The dashboards ship as JSON in `manifests/grafana-dashboards/`:

- **Next.js app** (`nextjs-app.json`): HTTP request rate by status, 5xx error rate, p95 request duration, and Node.js heap usage, all filtered by an `app` template variable.
- **OpenCost spend** (`opencost.json`): hourly cost by namespace, CPU and RAM hourly rates, and persistent volume cost.

Load them into a cluster with the helper script:

```bash
scripts/load-dashboards.sh --namespace monitoring
```

It wraps each dashboard in a ConfigMap carrying the `grafana_dashboard=1`
sidecar label, which the kube-prometheus-stack Grafana sidecar imports within
about a minute. The GitOps install enables the same sidecar so dashboards
committed to git appear automatically.

## Cost tracking with OpenCost

OpenCost is installed into the `monitoring` namespace and configured to read
allocation data from the in-cluster Prometheus. It writes cost metrics such as
`node_cpu_hourly_cost`, `node_ram_hourly_cost`, and `pv_hourly_cost` back into
Prometheus through a ServiceMonitor, which the bundled OpenCost dashboard then
queries. This gives per-namespace spend with no external billing integration.

## Bundled alerts

The `PrometheusRule` in `manifests/prometheus-rules/app-rules.yaml` defines:

- `KubePodCrashLooping`: more than five restarts in ten minutes.
- `KubePersistentVolumeFillingUp`: predicted full within six hours.
- `IngressNginxHigh5xxRate`: over 5 percent 5xx for five minutes.
- `IngressNginxHighLatency`: p99 above two seconds for five minutes.
- `CertManagerCertificateExpirySoon`: a certificate expiring within fourteen days.

Apply it with `kubectl apply -f manifests/prometheus-rules/app-rules.yaml`. The
node and memory pressure alerts come from kube-prometheus-stack defaults.

Configure receivers in `manifests/values-alertmanager.yaml`. The Slack webhook
is read from a Kubernetes Secret named `alertmanager-slack`, which the install
script creates when you pass `--slack-webhook`, so the URL never lands in git.

## Log queries

Grafana, then Explore, then Loki:

```logql
{namespace="default", app="my-app"} |= "error"
```

```logql
sum by (status) (rate({app="my-app"}[5m]))
```

Indexed labels are kept small (namespace, app, pod). Everything else stays in
the log line, which is why Loki is cheap.

## What is intentionally missing

- **Distributed tracing**. Add Tempo and OpenTelemetry if you need it. We do not bundle it because most Next.js production deployments do not need it.
- **Long-term metric storage**. Prometheus stores fifteen days by default. For longer retention, point at Mimir or Thanos.
- **APM (DataDog, New Relic)**. Pick one if you already pay for it. Not bundled here.

## Total cost

Self-hosted on a 3-node cluster at DigitalOcean prices:

- Cluster: about 36 USD per month (3x s-2vcpu-4gb).
- Persistent disks for Prometheus and Loki: about 20 USD per month.
- LoadBalancer for ingress: 12 USD per month.

Roughly 70 USD per month for the platform stack, hosting an unlimited number of
apps. The OpenCost dashboard shows you how that splits across namespaces.
