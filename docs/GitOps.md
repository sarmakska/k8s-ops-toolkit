# GitOps with ArgoCD

The install script is the fastest way to a working platform, but once the
platform is something you maintain, you want it reconciled from git: drift
self-heals, every change goes through a pull request, and the cluster state is
whatever the repository says it is. The `gitops/argocd` directory describes the
same pinned platform as an ArgoCD app-of-apps.

## Layout

```
gitops/argocd/
  root.yaml              # the app-of-apps: one Application that owns the rest
  apps/
    ingress-nginx.yaml
    cert-manager.yaml
    kube-prometheus-stack.yaml
    loki.yaml
    promtail.yaml
    opencost.yaml
```

`root.yaml` is a single `Application` whose source is the `gitops/argocd/apps`
path in this repository. ArgoCD renders every child `Application` in that
directory, and each child installs one upstream Helm chart at a pinned version.

## Install

You need an ArgoCD already running in the cluster (namespace `argocd`). Then:

```bash
kubectl apply -n argocd -f gitops/argocd/root.yaml
```

ArgoCD syncs the root, which in turn syncs ingress-nginx, cert-manager,
kube-prometheus-stack, Loki, Promtail, and OpenCost. Every Application has
`automated` sync with `prune` and `selfHeal` enabled, so manual changes in the
cluster are reverted to match git.

## Pinned versions

The child Applications pin the same versions as `scripts/install.sh`:

| Component | Chart version |
| --- | --- |
| ingress-nginx | 4.12.1 |
| cert-manager | v1.17.1 |
| kube-prometheus-stack | 70.4.2 |
| loki | 6.29.0 |
| promtail | 6.16.6 |
| opencost | 2.1.3 |

The test suite asserts that these match the installer, so the two paths never
drift apart.

## What the script still does

A few things are not expressed as Applications because they are
environment-specific or secret-bearing:

- The `letsencrypt-prod` `ClusterIssuer` (needs your email).
- The Alertmanager Slack `Secret` (needs your webhook).
- The bundled Grafana dashboards and Prometheus rules.

Apply those once after the platform is up, or fold them into your own
Application of repository manifests. The dashboards load with
`scripts/load-dashboards.sh`, and the rules with
`kubectl apply -f manifests/prometheus-rules/app-rules.yaml`.

## Forking

If you fork the repository, change `repoURL` in `root.yaml` and each child
Application to your fork, and pin `targetRevision` to a tag rather than `main`
when you want a frozen platform.
