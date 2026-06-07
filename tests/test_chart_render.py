"""End-to-end tests that render charts/nextjs-app with Helm and assert on the
resulting Kubernetes objects. These exercise the main flow of the toolkit:
turning a container image plus values into a correct, internally consistent
set of manifests.
"""
from __future__ import annotations

from conftest import FIXTURES, by_kind, one, requires_helm

pytestmark = requires_helm

PRODUCTION = FIXTURES / "production.yaml"
MINIMAL = FIXTURES / "minimal.yaml"


def test_default_values_render_core_objects(render):
    objs = render()
    kinds = {o["kind"] for o in objs}
    # The defaults turn everything on.
    assert {"Deployment", "Service", "Ingress", "HorizontalPodAutoscaler",
            "PodDisruptionBudget", "ServiceMonitor"} <= kinds


def test_selector_matches_pod_labels(render):
    objs = render(release="web")
    dep = one(objs, "Deployment")
    selector = dep["spec"]["selector"]["matchLabels"]
    pod_labels = dep["spec"]["template"]["metadata"]["labels"]
    # Every selector key must be present on the pod template, otherwise the
    # Deployment would never own its pods.
    for key, value in selector.items():
        assert pod_labels.get(key) == value


def test_service_targets_container_port(render):
    objs = render(release="web")
    svc = one(objs, "Service")
    dep = one(objs, "Deployment")
    container = dep["spec"]["template"]["spec"]["containers"][0]
    port = container["ports"][0]
    # Service forwards to the named port; the container exposes that name.
    assert svc["spec"]["ports"][0]["targetPort"] == port["name"]
    assert port["containerPort"] == 3000


def test_service_selector_matches_service_monitor(render):
    objs = render(release="web")
    svc = one(objs, "Service")
    sm = one(objs, "ServiceMonitor")
    # The ServiceMonitor must select the Service the chart ships, or Prometheus
    # scrapes nothing.
    assert sm["spec"]["selector"]["matchLabels"].items() <= svc["spec"]["selector"].items()
    endpoint = sm["spec"]["endpoints"][0]
    assert endpoint["port"] == "http"
    assert endpoint["path"] == "/api/metrics"


def test_ingress_tls_wires_cert_manager(render):
    objs = render(release="web")
    ing = one(objs, "Ingress")
    ann = ing["metadata"]["annotations"]
    assert ann["cert-manager.io/cluster-issuer"] == "letsencrypt-prod"
    tls = ing["spec"]["tls"][0]
    assert tls["hosts"] == ["app.example.com"]
    assert tls["secretName"] == "web-tls"
    # Ingress backend must point at the Service port (80), not the container.
    backend = ing["spec"]["rules"][0]["http"]["paths"][0]["backend"]["service"]
    assert backend["name"] == "web"
    assert backend["port"]["number"] == 80


def test_minimal_disables_optional_objects(render):
    objs = render(release="worker", values_file=MINIMAL)
    kinds = {o["kind"] for o in objs}
    assert "Deployment" in kinds and "Service" in kinds
    # All the optional pieces are gated off.
    assert by_kind(objs, "Ingress") == []
    assert by_kind(objs, "HorizontalPodAutoscaler") == []
    assert by_kind(objs, "PodDisruptionBudget") == []
    assert by_kind(objs, "ServiceMonitor") == []


def test_production_fixture_full_shape(render):
    objs = render(release="web", values_file=PRODUCTION)
    dep = one(objs, "Deployment")
    spec = dep["spec"]
    assert spec["replicas"] == 3
    assert spec["strategy"]["type"] == "RollingUpdate"

    pod = spec["template"]["spec"]
    # Private registry pull secret threads through.
    assert {"name": "ghcr-creds"} in pod["imagePullSecrets"]
    # Hardened security context.
    assert pod["securityContext"]["runAsNonRoot"] is True
    container = pod["containers"][0]
    assert container["image"] == "ghcr.io/acme/web:v2.3.1"
    assert container["securityContext"]["allowPrivilegeEscalation"] is False

    # Inline and secret-backed env both present.
    env = container["env"]
    assert {"name": "NODE_ENV", "value": "production"} in env
    db = next(e for e in env if e["name"] == "DATABASE_URL")
    assert db["valueFrom"]["secretKeyRef"]["name"] == "web-secrets"
    # Whole-secret envFrom present.
    assert {"secretRef": {"name": "web-runtime"}} in container["envFrom"]

    hpa = one(objs, "HorizontalPodAutoscaler")
    assert hpa["spec"]["minReplicas"] == 3
    assert hpa["spec"]["maxReplicas"] == 20
    assert hpa["spec"]["metrics"][0]["resource"]["target"]["averageUtilization"] == 65

    pdb = one(objs, "PodDisruptionBudget")
    assert pdb["spec"]["minAvailable"] == 2

    ing = one(objs, "Ingress")
    assert ing["metadata"]["annotations"]["nginx.ingress.kubernetes.io/proxy-body-size"] == "32m"

    sm = one(objs, "ServiceMonitor")
    assert sm["metadata"]["labels"]["release"] == "monitoring"


def test_default_spreads_replicas_across_zone_and_host(render):
    pod = one(render(release="web"), "Deployment")["spec"]["template"]["spec"]
    # Graceful shutdown window is wired through.
    assert pod["terminationGracePeriodSeconds"] == 30
    constraints = pod["topologySpreadConstraints"]
    keys = [c["topologyKey"] for c in constraints]
    assert keys == ["topology.kubernetes.io/zone", "kubernetes.io/hostname"]
    for c in constraints:
        assert c["maxSkew"] == 1
        # Soft spread by default so pods are never left Pending on a full zone.
        assert c["whenUnsatisfiable"] == "ScheduleAnyway"
        # Each constraint must select this release's own pods, not the whole
        # namespace, or the spread would balance unrelated workloads.
        sel = c["labelSelector"]["matchLabels"]
        assert sel["app.kubernetes.io/instance"] == "web"


def test_production_fixture_scheduling_overrides(render):
    pod = one(render(release="web", values_file=PRODUCTION),
              "Deployment")["spec"]["template"]["spec"]
    assert pod["terminationGracePeriodSeconds"] == 45
    constraints = pod["topologySpreadConstraints"]
    # Production narrows the spread to zone only and makes it a hard rule.
    assert [c["topologyKey"] for c in constraints] == ["topology.kubernetes.io/zone"]
    assert constraints[0]["whenUnsatisfiable"] == "DoNotSchedule"
    assert {"key": "dedicated", "operator": "Equal", "value": "web",
            "effect": "NoSchedule"} in pod["tolerations"]


def test_minimal_omits_optional_scheduling(render):
    pod = one(render(release="worker", values_file=MINIMAL),
              "Deployment")["spec"]["template"]["spec"]
    # No nodeSelector, affinity or tolerations were set, so the keys must be
    # absent rather than rendered empty.
    assert "nodeSelector" not in pod
    assert "affinity" not in pod
    assert "tolerations" not in pod


def test_probes_use_health_path(render):
    objs = render(release="web", sets={"probes.liveness.path": "/healthz",
                                        "probes.readiness.path": "/healthz"})
    container = one(objs, "Deployment")["spec"]["template"]["spec"]["containers"][0]
    assert container["livenessProbe"]["httpGet"]["path"] == "/healthz"
    assert container["readinessProbe"]["httpGet"]["path"] == "/healthz"
