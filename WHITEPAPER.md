# k8s-ops-toolkit — whitepaper

## Why this exists

Most teams running Next.js on Kubernetes solve the same five problems
in the first month: ingress with TLS, autoscaling, metrics, log
aggregation, and alert routing. Each of those is a few hours of work.
Together they are a week of yak-shaving before the team can confidently
push to production.

The k8s-ops-toolkit is that week, written down. A Helm chart for the
app and an install script for the platform. Five commands, you have
production-grade infrastructure.

## What "production-grade" means here

We use a strict definition. Production-grade means:

1. **TLS by default** with automatic renewal.
2. **Autoscaling** off CPU at minimum, optionally off custom metrics.
3. **Pod disruption budget** so cluster maintenance does not take you down.
4. **Metrics** scraped, dashboarded, alertable.
5. **Logs** centralised, queryable, retainable.
6. **Health probes** that catch broken deploys.
7. **Rolling updates** with maxSurge and maxUnavailable tuned correctly.

If any one of these is missing, you are not production-grade. The
toolkit ensures none of them are.

## Architecture decisions

### Why Helm, not raw yaml or Kustomize

Helm is the lingua franca for Kubernetes app distribution. Every
operator, every CI/CD platform, every cluster-as-a-service product
knows how to consume a Helm chart. Kustomize is more elegant for some
problems but ecosystem support is thinner. Raw yaml is unmaintainable
once you have more than two environments.

### Why ingress-nginx, not Traefik or HAProxy

ingress-nginx is the most-deployed ingress in the wild. Documentation,
examples, and Stack Overflow answers are all biased toward it.
Performance is fine for any non-Twitter-scale workload. Traefik is
elegant; HAProxy is fast; nginx is what most teams actually run.

### Why kube-prometheus-stack, not a custom Prometheus

The chart bundles Prometheus + Grafana + Alertmanager + node exporters
+ kube-state-metrics + ServiceMonitor CRD. Self-installing all of these
correctly takes two days. The kube-prometheus-stack chart does it in 90
seconds. We do not need to be opinionated here; the upstream stack is
correct.

### Why Loki, not ELK

Loki indexes labels, not log content. That is the cost optimisation:
storage is cheap, indexing is expensive. For SME-scale log volumes
(under 100GB/day), Loki is roughly an order of magnitude cheaper than
Elasticsearch and the query experience inside Grafana is better than
Kibana for most ops tasks.

If your log volumes are above 1TB/day, Elasticsearch starts to win on
ergonomics. We are not solving that case.

### Why no service mesh

Service meshes solve real problems: mTLS between services, traffic
splitting, retry policies, circuit breaking. They also add operational
complexity, latency, and a learning curve. For Next.js apps that are
mostly HTTP-in HTTP-out and occasionally talk to a database, a mesh is
overkill. If you reach the point where you need one, you are past what
this toolkit is solving.

## What this saves you

Time, mostly. A senior engineer setting up the equivalent stack
hand-rolled spends 3-5 days. Spread across a small team that is closer
to a week and a half. The toolkit collapses that to an afternoon.

Money, secondarily. The recommended platform footprint runs at roughly
$70/month on DigitalOcean for an arbitrary number of apps. If you were
buying a managed equivalent (Render, Fly, Railway), the price-per-app
adds up faster.

Operational confidence, mostly. The pre-baked alerts catch the things
that actually go wrong: pods crashing, certificates expiring, ingress
returning 5xx, disk filling. You do not learn these the hard way.

## What this does not solve

- Application-level concerns: code quality, business logic, data integrity.
- Multi-region failover. Single cluster, single region, by design.
- Compliance frameworks beyond the basics. SOC2, ISO 27001, HIPAA are out of scope; the toolkit is foundational not certifying.
- Distributed tracing. Add it if you need it; it is not bundled.

## Recommended companion repos

- [terraform-stack](https://github.com/sarmakska/terraform-stack) provisions the cluster + DNS + storage.
- [agent-orchestrator](https://github.com/sarmakska/agent-orchestrator) is one example of an app that fits this chart.

## Licence

MIT. Use it, fork it, build on it. Attribution appreciated but not required.

## Built by Sarma Linux

Solo engineer, UK. The toolkit is the platform stack I run for my own
projects, packaged so others can run the same thing.
