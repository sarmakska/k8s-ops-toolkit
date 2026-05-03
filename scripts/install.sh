#!/usr/bin/env bash
# Install the full k8s-ops-toolkit stack: ingress-nginx, cert-manager,
# observability (Prometheus + Grafana + Loki + Alertmanager).
set -euo pipefail

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

echo "→ Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.publishService.enabled=true

echo "→ Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

sleep 15  # Wait for cert-manager webhook to be ready

echo "→ Creating Let's Encrypt issuer..."
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

echo "→ Installing Prometheus stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=changeme \
  --set grafana.ingress.enabled=true \
  --set "grafana.ingress.hosts[0]=grafana.$DOMAIN" \
  --set "grafana.ingress.tls[0].secretName=grafana-tls" \
  --set "grafana.ingress.tls[0].hosts[0]=grafana.$DOMAIN" \
  --set "grafana.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod"

echo "→ Installing Loki..."
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

if [[ -n "$SLACK_WEBHOOK" ]]; then
  echo "→ Configuring Alertmanager Slack webhook..."
  kubectl create secret generic alertmanager-slack \
    --namespace monitoring \
    --from-literal=url="$SLACK_WEBHOOK" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo ""
echo "✓ Install complete."
echo ""
echo "Grafana:    https://grafana.$DOMAIN"
echo "  user:     admin"
echo "  password: changeme  (change immediately)"
echo ""
echo "Next steps:"
echo "  helm install my-app ./charts/nextjs-app --set ingress.host=app.$DOMAIN ..."
