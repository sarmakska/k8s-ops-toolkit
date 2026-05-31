#!/usr/bin/env bash
# Load the bundled Grafana dashboards into the cluster as ConfigMaps
# carrying the grafana_dashboard sidecar label, so the kube-prometheus-stack
# Grafana sidecar imports them automatically.
set -euo pipefail

NAMESPACE="monitoring"
DASHBOARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/manifests/grafana-dashboards"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

if [[ ! -d "$DASHBOARD_DIR" ]]; then
  echo "Dashboard directory not found: $DASHBOARD_DIR" >&2
  exit 1
fi

shopt -s nullglob
for dashboard in "$DASHBOARD_DIR"/*.json; do
  name="grafana-dashboard-$(basename "$dashboard" .json)"
  echo "Loading $name into namespace $NAMESPACE"
  kubectl create configmap "$name" \
    --namespace "$NAMESPACE" \
    --from-file="$(basename "$dashboard")=$dashboard" \
    --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml \
    | kubectl apply -f -
done

echo "Done. Grafana imports labelled dashboards within about a minute."
