"""Tests for the static manifests the toolkit ships: the GitOps ArgoCD
Applications, the bundled Grafana dashboards, and the Prometheus rules. These
do not need Helm and guard against drift such as a stray unpinned chart
version or an invalid dashboard JSON.
"""
from __future__ import annotations

import json
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
GITOPS_APPS = REPO_ROOT / "gitops" / "argocd" / "apps"
DASHBOARDS = REPO_ROOT / "manifests" / "grafana-dashboards"
RULES = REPO_ROOT / "manifests" / "prometheus-rules"


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def test_argocd_root_is_app_of_apps():
    root = _load(REPO_ROOT / "gitops" / "argocd" / "root.yaml")
    assert root["kind"] == "Application"
    assert root["spec"]["source"]["path"] == "gitops/argocd/apps"
    assert root["spec"]["syncPolicy"]["automated"]["selfHeal"] is True


def test_every_gitops_app_pins_a_chart_version():
    apps = list(GITOPS_APPS.glob("*.yaml"))
    expected = {"ingress-nginx", "cert-manager", "kube-prometheus-stack",
                "loki", "promtail", "opencost"}
    assert {a.stem for a in apps} == expected
    for app in apps:
        doc = _load(app)
        assert doc["kind"] == "Application"
        src = doc["spec"]["source"]
        # A pinned, non-floating chart version is mandatory for reproducible
        # GitOps syncs.
        assert "chart" in src, f"{app.name} has no chart"
        rev = src["targetRevision"]
        assert rev and rev not in ("latest", "*", ""), f"{app.name} is not pinned"


def test_gitops_versions_match_install_script():
    script = (REPO_ROOT / "scripts" / "install.sh").read_text()
    versions = {
        "ingress-nginx": "4.12.1",
        "cert-manager": "v1.17.1",
        "kube-prometheus-stack": "70.4.2",
        "loki": "6.29.0",
        "promtail": "6.16.6",
        "opencost": "2.1.3",
    }
    for name, version in versions.items():
        app = _load(GITOPS_APPS / f"{name}.yaml")
        assert app["spec"]["source"]["targetRevision"] == version
        # The same pin must appear in the imperative installer.
        assert version in script, f"{version} for {name} missing from install.sh"


def test_dashboards_are_valid_json_with_uids():
    files = list(DASHBOARDS.glob("*.json"))
    assert {f.stem for f in files} == {"nextjs-app", "opencost"}
    for f in files:
        doc = json.loads(f.read_text())
        assert doc["uid"], f"{f.name} has no uid"
        assert doc["title"], f"{f.name} has no title"
        assert doc["panels"], f"{f.name} has no panels"


def test_prometheus_rules_define_expected_alerts():
    rule = _load(RULES / "app-rules.yaml")
    assert rule["kind"] == "PrometheusRule"
    alerts = {
        r["alert"]
        for group in rule["spec"]["groups"]
        for r in group["rules"]
    }
    assert {"KubePodCrashLooping", "IngressNginxHigh5xxRate",
            "CertManagerCertificateExpirySoon"} <= alerts
