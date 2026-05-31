# Roadmap

The toolkit is opinionated and small on purpose. Roadmap items are the ones
that fit that posture.

## Now

- Helm chart for Next.js apps with deployment, service, ingress, HPA, PDB, ServiceMonitor, and a hardened security context.
- Version-pinned bootstrap script for ingress-nginx, cert-manager, kube-prometheus-stack, Loki 3.x with Promtail, and OpenCost.
- GitOps install through an ArgoCD app-of-apps that pins the same component versions.
- Bundled Grafana dashboards: Next.js app and OpenCost spend.
- Bundled Prometheus alert rules.
- End-to-end test suite that renders the chart with Helm and asserts on the objects.

## Next

- **HPA on custom metrics.** Pattern and values for scaling on requests per second from the ServiceMonitor instead of CPU.
- **ingress-nginx canary traffic split.** Split traffic between two Helm releases using canary annotations. Lower complexity than a mesh.
- **Backup hooks.** Velero install path for namespaced backup and restore.
- **Flux variant.** A Flux Kustomization mirroring the ArgoCD app-of-apps, for teams standardised on Flux.

## Maybe

- A second chart for Python (FastAPI) apps with the same shape. Most of the work is already done; the question is whether to keep the project tightly Next.js focused or broaden it.
- A platform-in-a-box wrapper that combines this repo with terraform-stack so you provision the cluster, DNS, and the full stack with one command.
- An OpenTelemetry collector chart with sane defaults for trace shipping to Tempo.

## Not planned

- A service mesh. Out of scope.
- A custom operator. The chart is plain Helm and stays that way.
- Multi-cluster federation. If you need that, you are past what this toolkit is for.
- A web UI for the chart. Helm is the UI.

## How to contribute

Open an issue describing the gap. PRs welcome for new dashboards or alert rules.
For chart template changes, please discuss first, because the chart's smallness
is a feature.
