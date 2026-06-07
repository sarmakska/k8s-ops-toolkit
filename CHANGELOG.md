# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0]

### Added

- Zone-aware scheduling on the `nextjs-app` chart. By default the Deployment carries `topologySpreadConstraints` that spread its replicas across `topology.kubernetes.io/zone` first, then `kubernetes.io/hostname`, with `maxSkew: 1` and a per-release label selector, so a single zone or node failure cannot take the whole app down. This is the resilience the PodDisruptionBudget already assumes. The spread is configurable under `scheduling.spread` (toggle, topology keys, and `ScheduleAnyway` versus `DoNotSchedule`) and falls back cleanly on single-node clusters.
- Optional `scheduling.nodeSelector`, `scheduling.affinity`, and `scheduling.tolerations`, passed through verbatim when set and omitted entirely when empty, plus a configurable `terminationGracePeriodSeconds` (default 30) so Next.js can drain in-flight requests on a deploy.
- Three end-to-end tests covering the default zone-and-host spread, the production fixture's narrowed hard-spread and toleration overrides, and the absence of optional scheduling keys when unset, taking the chart render suite to 16 tests.

### Changed

- Chart bumped to 1.2.0. The production test fixture now exercises a zone-only `DoNotSchedule` spread, a dedicated-node toleration, and a 45-second graceful-shutdown window.

## [1.1.0]

### Added

- OpenCost 2.1.3 for per-namespace spend tracking, installed into the `monitoring` namespace and reading allocation data from the in-cluster Prometheus, with a bundled "OpenCost spend" Grafana dashboard.
- GitOps install path under `gitops/argocd`: an app-of-apps root and child Applications that reconcile ingress-nginx, cert-manager, kube-prometheus-stack, Loki, Promtail, and OpenCost at the same pinned versions as the installer.
- `manifests/grafana-dashboards/` with the "Next.js app" and "OpenCost spend" dashboards, plus `scripts/load-dashboards.sh` to load them as Grafana sidecar ConfigMaps.
- `manifests/prometheus-rules/app-rules.yaml`: a `PrometheusRule` with the crash-loop, volume-filling, ingress 5xx, ingress latency, and certificate expiry alerts the docs describe.
- `manifests/values-alertmanager.yaml` and `manifests/values-loki.yaml` for receiver and Loki schema configuration.
- Chart `_helpers.tpl` with shared label and selector templates, a `PodDisruptionBudget` template, a tuned rolling update strategy, hardened pod and container security contexts, image pull secrets, ingress annotations, and whole-Secret `envFrom` injection.
- End-to-end pytest suite under `tests/` that renders the chart with real Helm and asserts on the resulting Kubernetes objects, with `production` and `minimal` fixtures, plus static checks that the GitOps Applications and the installer pin matching chart versions.
- CI jobs for the pytest suite, dashboard JSON validation, and manifest and GitOps YAML validation, alongside the existing Helm lint and ShellCheck jobs.

### Changed

- Upgraded the pinned platform to current versions: ingress-nginx 4.12.1, cert-manager v1.17.1, kube-prometheus-stack 70.4.2, and Loki 3.x via the `loki` 6.29.0 chart with Promtail 6.16.6, replacing the deprecated `loki-stack` chart.
- `scripts/install.sh` now pins every upstream chart version, installs OpenCost, waits for the cert-manager webhook with `--wait`, sources the Alertmanager Slack URL from a Secret rather than inlining it, and loads the bundled dashboards and alert rules.
- Chart bumped to 1.1.0. The Service now publishes port 80 and targets the named container port, and all objects carry consistent `app.kubernetes.io` labels from the shared helpers.
- Rewrote the README, `docs/Architecture.md`, `docs/Helm-Chart.md`, `docs/Observability.md`, `docs/Quick-Start.md`, `docs/Roadmap.md`, the whitepaper, and every wiki page to match the current chart values and platform.
- Updated CI to Helm v3.17.1 and security contact to security@sarmalinux.com with an explicit supported-versions table.

### Fixed

- `docs/Helm-Chart.md` documented value keys that did not exist in the chart (`replicaCount`, `minReplicas`, `serviceMonitor.enabled`, `probe.path`); the reference now matches `values.yaml` exactly.
- Documentation referenced `manifests/grafana-dashboards/`, `manifests/prometheus-rules/`, `values-alertmanager.yaml`, a `pdb.yaml` template, and `_helpers.tpl` that did not exist; these are now present.
