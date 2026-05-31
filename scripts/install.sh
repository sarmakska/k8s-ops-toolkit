#!/usr/bin/env bash
# Install the full k8s-ops-toolkit platform on a fresh cluster:
# ingress-nginx, cert-manager, kube-prometheus-stack (Prometheus, Grafana,
# Alertmanager), Loki 3.x for logs, Promtail for log shipping, and OpenCost
# for spend tracking. All upstream chart versions are pinned so an install
# is reproducible. For a GitOps install instead, see gitops/argocd.
set -euo pipefail

# Pinned upstream chart versions. Bump these together and test before
# committing. The matching app versions are recorded in CHANGELOG.md.
INGRESS_NGINX_VERSION="4.12.1"
CERT_MANAGER_VERSION="v1.17.1"
KUBE_PROM_STACK_VERSION="70.4.2"
LOKI_VERSION="6.29.0"
PROMTAIL_VERSION="6.16.6"
OPENCOST_VERSION="2.1.3"

DOMAIN=""
EMAIL=""
SLACK_WEBHOOK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

[[ -z "$DOMAIN" || -z "$EMAIL" ]] && { echo "Usage: $0 --domain example.com --email you@example.com [--slack-webhook URL]"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Installing ingress-nginx ($INGRESS_NGINX_VERSION)..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version "$INGRESS_NGINX_VERSION" \
  --namespace ingress-nginx --create-namespace \
  --set controller.publishService.enabled=true

echo "==> Installing cert-manager ($CERT_MANAGER_VERSION)..."
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --version "$CERT_MANAGER_VERSION" \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait

echo "==> Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo "==> Installing kube-prometheus-stack ($KUBE_PROM_STACK_VERSION)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

# When a Slack webhook is supplied, create its Secret first so Alertmanager
# can mount it, then apply the receiver values that reference it.
ALERTMANAGER_ARGS=""
if [[ -n "$SLACK_WEBHOOK" ]]; then
  echo "==> Creating Alertmanager Slack secret..."
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic alertmanager-slack \
    --namespace monitoring \
    --from-literal=url="$SLACK_WEBHOOK" \
    --dry-run=client -o yaml | kubectl apply -f -
  ALERTMANAGER_ARGS="-f $REPO_ROOT/manifests/values-alertmanager.yaml"
fi

# shellcheck disable=SC2086 # ALERTMANAGER_ARGS is an intentional word split
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version "$KUBE_PROM_STACK_VERSION" \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=changeme \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.label=grafana_dashboard \
  --set grafana.ingress.enabled=true \
  --set "grafana.ingress.hosts[0]=grafana.$DOMAIN" \
  --set "grafana.ingress.tls[0].secretName=grafana-tls" \
  --set "grafana.ingress.tls[0].hosts[0]=grafana.$DOMAIN" \
  --set "grafana.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod" \
  ${ALERTMANAGER_ARGS}

echo "==> Installing Loki ($LOKI_VERSION) and Promtail ($PROMTAIL_VERSION)..."
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install loki grafana/loki \
  --version "$LOKI_VERSION" \
  --namespace monitoring \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --set singleBinary.persistence.enabled=true \
  --set singleBinary.persistence.size=10Gi \
  --set backend.replicas=0 --set read.replicas=0 --set write.replicas=0 \
  --set chunksCache.enabled=false --set resultsCache.enabled=false \
  -f "$REPO_ROOT/manifests/values-loki.yaml"
helm upgrade --install promtail grafana/promtail \
  --version "$PROMTAIL_VERSION" \
  --namespace monitoring \
  --set "config.clients[0].url=http://loki:3100/loki/api/v1/push"

echo "==> Installing OpenCost ($OPENCOST_VERSION)..."
helm repo add opencost https://opencost.github.io/opencost-helm-chart >/dev/null
helm repo update >/dev/null
helm upgrade --install opencost opencost/opencost \
  --version "$OPENCOST_VERSION" \
  --namespace monitoring \
  --set opencost.prometheus.internal.enabled=true \
  --set opencost.prometheus.internal.namespaceName=monitoring \
  --set opencost.prometheus.internal.serviceName=monitoring-kube-prometheus-prometheus \
  --set opencost.prometheus.internal.port=9090 \
  --set opencost.metrics.serviceMonitor.enabled=true \
  --set "opencost.metrics.serviceMonitor.additionalLabels.release=monitoring"

echo "==> Loading bundled Grafana dashboards..."
"$SCRIPT_DIR/load-dashboards.sh" --namespace monitoring

echo "==> Applying bundled Prometheus alert rules..."
kubectl apply -f "$REPO_ROOT/manifests/prometheus-rules/app-rules.yaml"

echo ""
echo "Install complete."
echo ""
echo "Grafana:    https://grafana.$DOMAIN"
echo "  user:     admin"
echo "  password: changeme  (change immediately)"
echo ""
echo "Next steps:"
echo "  helm install my-app $REPO_ROOT/charts/nextjs-app --set ingress.host=app.$DOMAIN ..."
