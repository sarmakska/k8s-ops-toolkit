# Quick start

A handful of commands and you have a Next.js app on Kubernetes with TLS,
metrics, logs, alerts, and cost tracking.

## 0. Prerequisites

- A Kubernetes cluster you can reach (1.28+). DigitalOcean, EKS, GKE, AKS, or kind for local.
- `kubectl` pointed at the cluster.
- `helm` 3.16+.
- A domain whose A record (or CNAME) you can point at the ingress.

## 1. Clone

```bash
git clone https://github.com/sarmakska/k8s-ops-toolkit.git
cd k8s-ops-toolkit
```

## 2. Install the platform stack

```bash
./scripts/install.sh \
  --email you@example.com \
  --domain apps.example.com \
  --slack-webhook https://hooks.slack.com/...   # optional
```

This installs ingress-nginx, cert-manager (with a Let's Encrypt ClusterIssuer
using the email you passed), kube-prometheus-stack, Loki 3.x with Promtail, and
OpenCost, then loads the bundled dashboards and alert rules. Every chart version
is pinned in the script. About eight minutes on a 3-node cluster.

Prefer GitOps? Apply the ArgoCD app-of-apps instead of running the script:

```bash
kubectl apply -n argocd -f gitops/argocd/root.yaml
```

## 3. Deploy your Next.js app

```bash
helm install my-app charts/nextjs-app \
  --set image.repository=ghcr.io/you/my-app \
  --set image.tag=v1.0.0 \
  --set ingress.host=app.example.com \
  --set ingress.tls.enabled=true
```

cert-manager issues the certificate within about a minute of the DNS record
resolving.

## 4. View metrics, logs, and cost

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# open http://localhost:3000  (default: admin / prom-operator)
```

Bundled dashboards: `Next.js app` and `OpenCost spend`. Explore logs through the
Loki datasource.

## 5. Add an alert

Edit `manifests/prometheus-rules/app-rules.yaml`, then:

```bash
kubectl apply -f manifests/prometheus-rules/app-rules.yaml
```

Alertmanager picks it up within thirty seconds.

## What you have now

- App reachable at `https://app.example.com` with a valid Let's Encrypt certificate.
- Prometheus scraping the app through the chart's ServiceMonitor.
- Logs centralised in Loki, queryable from Grafana.
- OpenCost showing per-namespace spend.
- Default alerts routing into Alertmanager (configure receivers in `manifests/values-alertmanager.yaml`).

## Common gotchas

- **Ingress IP pending.** Some clusters take 60 to 120 seconds to assign a LoadBalancer IP. Check with `kubectl get svc -n ingress-nginx`.
- **Certificate stuck.** Inspect with `kubectl describe certificate -A`. The two common causes are DNS that has not propagated yet or a placeholder email address.
- **Grafana credentials.** The default `admin / prom-operator` is set by kube-prometheus-stack. Change it on first login.
- **App not in Prometheus.** Set `monitoring.serviceMonitorLabels.release` to your monitoring release name so the operator selects the ServiceMonitor.

## Next: read [Helm-Chart](Helm-Chart.md) and [Observability](Observability.md).
