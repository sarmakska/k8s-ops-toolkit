# Quick start

Five commands. You will have a Next.js app on Kubernetes with TLS,
metrics, logs, and alerts.

## 0. Prerequisites

- A Kubernetes cluster you can reach (1.28+). DigitalOcean, EKS, GKE, AKS, or kind for local.
- `kubectl` pointed at the cluster.
- `helm` 3.13+.
- A domain whose A record (or CNAME) you can point at the ingress.

## 1. Clone

```bash
git clone https://github.com/sarmakska/k8s-ops-toolkit.git
cd k8s-ops-toolkit
```

## 2. Install the platform stack

```bash
./scripts/install.sh \
  --email=you@example.com \
  --domain=apps.example.com
```

This installs ingress-nginx, cert-manager (with a Let's Encrypt
ClusterIssuer using the email you passed), kube-prometheus-stack,
and Loki + Promtail. ~3 minutes on a 3-node cluster.

## 3. Deploy your Next.js app

```bash
helm install my-app charts/nextjs-app \
  --set image.repository=ghcr.io/you/my-app \
  --set image.tag=v1.0.0 \
  --set ingress.host=app.example.com \
  --set ingress.tls.enabled=true
```

cert-manager will issue the certificate within 60 seconds of the DNS
record resolving.

## 4. View metrics and logs

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# open http://localhost:3000  (default: admin / prom-operator)
```

Pre-baked dashboards: `Cluster Overview`, `Ingress nginx`, `Next.js app`.

## 5. Add an alert

Edit `manifests/prometheus-rules/app-rules.yaml`, then:

```bash
kubectl apply -f manifests/prometheus-rules/app-rules.yaml
```

Alertmanager picks it up within 30 seconds.

## What you have now

- App reachable at `https://app.example.com` with a valid Let's Encrypt cert.
- Prometheus scraping every pod with `prometheus.io/scrape=true`.
- Logs centralised in Loki, queryable from Grafana.
- Default alerts firing into Alertmanager (configure receivers in `values-alertmanager.yaml`).

## Common gotchas

- **Ingress IP not pending.** Some clusters take 60–120 seconds to assign a LoadBalancer IP. `kubectl get svc -n ingress-nginx` to check.
- **Certificate stuck.** Inspect with `kubectl describe certificate -A`. The two common causes are DNS not propagated yet or the email address being a placeholder.
- **Grafana credentials.** The default `admin / prom-operator` is set by kube-prometheus-stack. Change it on first login.

## Next: read [Helm-Chart](Helm-Chart.md) and [Observability](Observability.md).
