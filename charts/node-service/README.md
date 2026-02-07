# Node.js Service Helm Chart

A production-ready Helm chart for deploying Node.js applications with enforced organizational standards. This chart serves as the single reusable standard for deploying ALL Node.js workloads across the organization.

## Overview

This chart supports four application types, each with pre-configured settings optimized for their use case:

| Type     | Description                     | Port | Vault (default) | Ingress              |
| -------- | ------------------------------- | ---- | --------------- | -------------------- |
| `api`    | REST/GraphQL API services       | 8080 | ✅ Enabled      | `/api/*`             |
| `web`    | Frontend/static content servers | 3000 | ❌ Disabled     | `/`                  |
| `worker` | Background job processors       | None | ✅ Enabled      | None                 |
| `stream` | WebSocket/streaming services    | 8080 | ✅ Enabled      | `/ws/*`, `/stream/*` |

> Vault can be explicitly enabled or disabled for any type by setting `vault.enabled` in values.

## Installation

```bash
helm install my-release ./charts/node-service \
  --set name=user-service \
  --set service=user-service \
  --set type=api \
  --set image.tag=v1.0.0
```

## Configuration

### Required Parameters

| Parameter | Description                                                                                                                                                                                                | Example        |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| `name`    | Unique identifier for this deployment. Used as the GitHub repository name, container image name, Kubernetes resource name, Vault app path, and labels. Image is derived as `<registry>/<org>/<name>:<tag>` | `user-service` |
| `service` | Service group name. Used only for the ingress host subdomain (`<service>.<baseDomain>`) and as a label for grouping related deployments                                                                    | `user-service` |

### Optional Parameters

| Parameter                                    | Default        | Description                                                                                 |
| -------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------- |
| `type`                                       | `api`          | Application type: `api`, `web`, `worker`, or `stream`                                       |
| `image.tag`                                  | `latest`       | Container image tag                                                                         |
| `image.pullPolicy`                           | `IfNotPresent` | Kubernetes image pull policy: `Always`, `IfNotPresent`, `Never`                             |
| `vault.enabled`                              | (auto)         | Override Vault injection. Auto-detected by type if omitted (disabled for web, else enabled) |
| `ingress.enabled`                            | `true`         | Enable external ingress (ignored for `worker` type)                                         |
| `size`                                       | `M`            | Resource size preset: `XS`, `S`, `M`, `L`, `XL`                                             |
| `replicaCount`                               | `1`            | Number of replicas (ignored when autoscaling is enabled)                                    |
| `autoscaling.enabled`                        | `false`        | Enable Horizontal Pod Autoscaler                                                            |
| `autoscaling.minReplicas`                    | `2`            | Minimum replicas when HPA is enabled                                                        |
| `autoscaling.maxReplicas`                    | `10`           | Maximum replicas when HPA is enabled                                                        |
| `autoscaling.targetCPUUtilizationPercentage` | `70`           | Target CPU utilization for scaling                                                          |
| `config`                                     | `{}`           | Key-value pairs injected as environment variables via ConfigMap                             |

### Global Parameters (from cluster values)

These values are provided by the cluster configuration and should not be overridden:

| Parameter             | Description                           | Example                        |
| --------------------- | ------------------------------------- | ------------------------------ |
| `global.baseDomain`   | Base domain for ingress hosts         | `example.com`                  |
| `global.environment`  | Environment name used in Vault paths  | `dev`, `staging`, `production` |
| `global.registry`     | Container registry hostname           | `ghcr.io`                      |
| `global.organization` | Organization name within the registry | `shadow-library`               |

## Resource Size Presets

The `size` parameter maps to predefined resource requests and limits:

| Size | Memory Request | Memory Limit | CPU Request | CPU Limit | Use Case              |
| ---- | -------------- | ------------ | ----------- | --------- | --------------------- |
| `XS` | 64Mi           | 128Mi        | 50m         | 100m      | Development, testing  |
| `S`  | 128Mi          | 256Mi        | 100m        | 200m      | Small workloads       |
| `M`  | 256Mi          | 512Mi        | 250m        | 500m      | Standard workloads    |
| `L`  | 512Mi          | 1Gi          | 500m        | 1000m     | High-traffic services |
| `XL` | 1Gi            | 2Gi          | 1000m       | 2000m     | Heavy processing      |

## Enforced Standards

The following configurations are standardized across all deployments and cannot be modified.

### Container Registry

All images are pulled from the container registry defined in cluster values. The image is derived from the `name` field combined with global values:

```
<global.registry>/<global.organization>/<name>:<tag>
```

For example, with the default cluster values:

```
ghcr.io/shadow-library/user-service:v1.0.0
```

Since `name` is also the GitHub repository name, the image is automatically resolved. The registry and organization are centrally managed via cluster values, so no per-app image configuration is needed.

### Networking

**Service:**

- Type: `ClusterIP` (internal only, external access via Ingress)
- Services are only created for HTTP-serving types (`api`, `web`, `stream`)
- Workers do not create a Service resource

**Ingress:**

- Ingress class: `nginx`
- TLS is terminated before the cluster (e.g., at the load balancer or CDN); ingress handles plain HTTP only
- Host format: `<service>.<global.baseDomain>`
- Path routing based on type (no URL rewriting - apps handle their own prefixes)

### Health Checks

All applications must expose health endpoints on port `8081`:

| Probe     | Endpoint            | Initial Delay | Period | Timeout | Failure Threshold |
| --------- | ------------------- | ------------- | ------ | ------- | ----------------- |
| Liveness  | `GET /health/live`  | 10s           | 10s    | 5s      | 3                 |
| Readiness | `GET /health/ready` | 10s           | 10s    | 5s      | 3                 |

### Vault Integration

Vault integration is controlled by the `vault.enabled` parameter. When omitted, it is auto-detected based on the application type:

| Type     | Default Vault State |
| -------- | ------------------- |
| `api`    | Enabled             |
| `worker` | Enabled             |
| `stream` | Enabled             |
| `web`    | Disabled            |

This default behavior can be overridden explicitly:

```yaml
# Enable Vault for a web app that needs secrets
type: web
vault:
  enabled: true

# Disable Vault for an API that doesn't need secrets
type: api
vault:
  enabled: false
```

**Vault Server:**

```
http://vault.vault.svc.cluster.local:8200
```

**Authentication:**

- Method: Kubernetes auth
- Role: `<release-name>-<name>`

**Secret Paths (environment-based):**

| Secret Type   | Vault Path                    | Description                                          |
| ------------- | ----------------------------- | ---------------------------------------------------- |
| App Secrets   | `<environment>/apps/<name>`   | Application-specific secrets (unique per deployment) |
| Common Config | `<environment>/common/config` | Shared configuration across services                 |
| Common Keys   | `<environment>/common/keys`   | Certificates, JWT keys, encryption keys              |

**Mount Location:**

- Vault Agent Injector automatically mounts secrets into the pod
- All key files from common keys are available at `/etc/secrets/`

**Example paths for `user-service-api` in `production`:**

```
production/apps/user-service-api  → App-specific secrets (per unique name)
production/common/config          → Shared config
production/common/keys            → Key files → /etc/secrets/
```

### Security Context

All containers run with hardened security settings:

**Pod Level:**

```yaml
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
seccompProfile:
  type: RuntimeDefault
```

**Container Level:**

```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: 1000
capabilities:
  drop:
    - ALL
```

### Pod Scheduling

**Topology Spread:**

- Pods are spread across nodes for high availability
- `maxSkew: 1` with `ScheduleAnyway` policy using `kubernetes.io/hostname`

**Termination:**

- Grace period: 30 seconds
- Rolling update strategy with `maxSurge: 1` and `maxUnavailable: 0`

### Pod Disruption Budget

When autoscaling is enabled:

- `minAvailable: max(1, minReplicas - 1)` ensures availability during voluntary disruptions

## Example Configurations

### API Service

```yaml
name: user-service
service: user-service
type: api
image:
  tag: v2.1.0
size: M
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
config:
  LOG_LEVEL: info
  DATABASE_POOL_SIZE: '10'
```

### Web Frontend

```yaml
name: dashboard
service: dashboard
type: web
image:
  tag: v1.5.0
size: S
replicaCount: 2
config:
  API_BASE_URL: /api
```

### Background Worker

```yaml
name: email-worker
service: email-worker
type: worker
image:
  tag: v1.0.0
size: L
replicaCount: 3
config:
  QUEUE_CONCURRENCY: '5'
  RETRY_ATTEMPTS: '3'
```

### WebSocket Server

```yaml
name: notifications
service: notifications
type: stream
image:
  tag: v1.2.0
size: M
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
```

### Internal API (No Ingress)

```yaml
name: internal-api
service: internal-api
type: api
image:
  tag: v1.0.0
ingress:
  enabled: false
size: S
```

### Web App with Vault (Override Default)

```yaml
name: admin-panel
service: admin-panel
type: web
image:
  tag: v1.0.0
vault:
  enabled: true
size: S
config:
  API_BASE_URL: /api
```

### Multi-Component Service

Multiple deployments sharing the same ingress host via the `service` field:

```yaml
# API component → payment-gateway.example.com/api
name: payment-api
service: payment-gateway
type: api
image:
  tag: v3.0.0

# Worker component (no ingress)
name: payment-worker
service: payment-gateway
type: worker
image:
  tag: v3.0.0
```

## Generated Resources

Depending on configuration, the chart creates:

| Resource                | Condition                                             |
| ----------------------- | ----------------------------------------------------- |
| Deployment              | Always                                                |
| Service                 | When type is `api`, `web`, or `stream`                |
| ServiceAccount          | Always                                                |
| ConfigMap               | Always                                                |
| Ingress                 | When `ingress.enabled: true` and type is not `worker` |
| HorizontalPodAutoscaler | When `autoscaling.enabled: true`                      |
| PodDisruptionBudget     | When `autoscaling.enabled: true`                      |

## Application Requirements

To work with this chart, your Node.js application must:

1. **Health Endpoints**: Expose `/health/live` and `/health/ready` on port `8081`
2. **Port Configuration**: Listen on the correct port for your type (8080 for api/stream, 3000 for web)
3. **Path Handling**: Handle URL prefixes natively (`/api/*` for api, `/ws/*` or `/stream/*` for stream)
4. **Non-root User**: Run as UID 1000 (use appropriate base image)
5. **Read-only Filesystem**: Store temporary files in `/tmp` (emptyDir volume provided)
6. **Secrets Access**: Read Vault secrets from `/etc/secrets/` directory

## Troubleshooting

### View Deployment Status

```bash
kubectl get deployment <release>-<name> -n <namespace>
```

### View Pod Logs

```bash
kubectl logs -l app.kubernetes.io/name=<name> -n <namespace> -f
```

### Check HPA Status

```bash
kubectl get hpa <release>-<name> -n <namespace>
```

### Port Forward for Local Testing

```bash
kubectl port-forward svc/<release>-<name> 8080:80 -n <namespace>
```

### Describe Pod for Events

```bash
kubectl describe pod -l app.kubernetes.io/name=<name> -n <namespace>
```
