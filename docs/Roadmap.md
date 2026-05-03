# Roadmap

The toolkit is opinionated and small on purpose. Roadmap items are the
ones that fit that posture.

## Now

- Helm chart for Next.js apps with deployment, service, ingress, HPA, PDB, ServiceMonitor.
- Bootstrap script for ingress-nginx, cert-manager, kube-prometheus-stack, Loki + Promtail.
- Pre-baked Grafana dashboards: Cluster Overview, Ingress nginx, Next.js app.
- Pre-baked Prometheus alert rules.

## Next

- **Argo Rollouts integration.** Canary and blue-green deployments through values flags. Optional.
- **Istio-free traffic split.** Use ingress-nginx canary annotations to split traffic between two Helm releases. Lower complexity than a mesh.
- **Backup hooks.** Velero install script for namespaced backup/restore.
- **Cost dashboard.** Pre-baked Grafana dashboard reading kube-state-metrics + node prices to show spend per namespace.
- **HPA on custom metrics.** Pattern + values for scaling on requests-per-second from the ServiceMonitor instead of CPU.

## Maybe

- A second chart for Python (FastAPI) apps with the same shape. Most of the work is already done; the question is whether to keep the project tightly Next.js-focused or broaden.
- A "platform-in-a-box" wrapper that combines this repo with terraform-stack so you provision the cluster + DNS + the full observability stack with one command.
- An OpenTelemetry collector chart with sane defaults for log/trace shipping to Tempo.

## Not planned

- A service mesh. Out of scope.
- A custom operator. The chart is plain Helm and stays that way.
- Multi-cluster federation. If you need that, you are past what this toolkit is for.
- A web UI for the chart. Helm is the UI.

## How to contribute

Open an issue describing the gap. PRs welcome for new dashboards or
alert rules; for chart template changes, please discuss first — the
chart's smallness is a feature.
