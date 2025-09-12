# Helm SecureKit

Security, resilience, and observability **building blocks** for any Helm chart — delivered as a **Helm library chart** (no pods created). Add SecureKit as a dependency and get:

- Default-deny **NetworkPolicies** (with DNS egress allowed by default)
- Sensible **securityContexts** (drop ALL Linux capabilities, `RuntimeDefault` seccomp, runAsNonRoot)
- **PodDisruptionBudget** for safer rolling operations
- Optional **HorizontalPodAutoscaler**
- HTTP **liveness/readiness probes** helpers
- Optional **ServiceMonitor/PodMonitor** for Prometheus Operator
- Optional **Pod Security Admission** labels for namespaces you create

> SecureKit is **type: library**. It does not deploy workloads by itself. It exposes reusable templates and manifests you can enable from your own chart’s `values.yaml`.

---

## Contents

- [Why SecureKit?](#why-securekit)
- [Requirements](#requirements)
- [Install (Helm repo)](#install-helm-repo)
- [Use in an existing chart](#use-in-an-existing-chart)
- [Use the Starter chart](#use-the-starter-chart)
- [What gets installed?](#what-gets-installed)
- [Values reference](#values-reference)
- [Security defaults explained](#security-defaults-explained)
- [NetworkPolicy model](#networkpolicy-model)
- [HPA, PDB, Probes](#hpa-pdb-probes)
- [Observability (ServiceMonitor/PodMonitor)](#observability-servicemonitorpodmonitor)
- [Pod Security Admission labels](#pod-security-admission-labels)
- [Kyverno optional hardening](#kyverno-optional-hardening)
- [Compatibility matrix](#compatibility-matrix)
- [Troubleshooting](#troubleshooting)
- [Versioning & releases](#versioning--releases)
- [Contributing](#contributing)
- [Security policy](#security-policy)
- [License](#license)

---

## Why SecureKit?

Most application charts ship with minimal security and ops settings. SecureKit lets **any chart** opt into battle-tested defaults in a consistent way:

- **Fast**: one dependency, a few helper includes.
- **Portable**: uses GA Kubernetes APIs; extras are gated behind feature flags.
- **Composable**: you keep your chart’s structure and simply include SecureKit helpers.

---

## Requirements

- Kubernetes **>= 1.25**
- Helm **>= 3.8**
- (Optional) Prometheus Operator CRDs for ServiceMonitor/PodMonitor
- (Optional) Kyverno CRDs for Kyverno policies

---

## Install (Helm repo)

```bash
helm repo add helm-securekit https://azizhilal.github.io/helm-securekit
helm repo update
```

---

## Use in an existing chart

1. **Add dependency** in your chart’s `Chart.yaml`:

```yaml
dependencies:
  - name: helm-securekit
    version: 0.1.0
    repository: "https://azizhilal.github.io/helm-securekit"
```

2. **Call helpers** in your templates (e.g., `templates/deployment.yaml`):

```gotemplate
spec:
  template:
    metadata:
      labels:
        {{- include "securekit.labels" . | nindent 8 }}
    spec:
      securityContext:
        {{- include "securekit.podSecurityContext" . | nindent 8 }}
      containers:
        - name: {{ include "chart.name" . }}
          # ...
          securityContext:
            {{- include "securekit.containerSecurityContext" . | nindent 12 }}
          {{- if .Values.securekit.probes.http.enabled }}
          {{- include "securekit.probes.http" . | nindent 10 }}
          {{- end }}
```

3. **Toggle features** from your `values.yaml`:

```yaml
securekit:
  networkPolicy:
    enabled: true
    ingress:
      allowFromNamespaces: ["ingress-nginx"]
  pdb:
    enabled: true
  hpa:
    enabled: false
```

> NetworkPolicies, PDB, HPA, monitors, and PSA labels are created directly from SecureKit templates when their feature flags are enabled.

---

## Use the Starter chart

Scaffold a new app chart already wired to SecureKit:

```bash
helm create myapp --starter securekit-app
```

This produces a minimal Deployment/Service using the helpers and sane defaults. Adjust `values.yaml` as needed.

---

## What gets installed?

SecureKit ships **templates** that render into these Kubernetes objects when enabled:

- `NetworkPolicy` (default-deny + allow rules)
- `PodDisruptionBudget`
- `HorizontalPodAutoscaler`
- (Optional) `ServiceMonitor` and/or `PodMonitor` (if CRDs exist)
- (Optional) `Namespace` with Pod Security Admission (PSA) labels when your chart creates a namespace

Plus **helpers** you include in your own resources:

- `securekit.labels` — consistent labels
- `securekit.podSecurityContext` — pod-level security defaults
- `securekit.containerSecurityContext` — container-level security defaults
- `securekit.probes.http` — HTTP liveness/readiness probes

---

## Values reference

```yaml
securekit:
  enabled: true

  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    seccompProfile: { type: RuntimeDefault }
    capabilities: { drop: ["ALL"] }

  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001

  podSecurityAdmission:
    enabled: true
    level: "restricted" # PSA level
    version: "latest"

  networkPolicy:
    enabled: true
    ingress:
      defaultDeny: true
      allowFromNamespaces: [] # ["ingress-nginx", "monitoring"]
      allowFromCIDRs: [] # ["10.0.0.0/8"]
      allowSameNamespace: true
    egress:
      defaultDeny: true
      allowToNamespaces: ["kube-system"] # for DNS
      allowToCIDRs: []
      allowDNS: true # TCP/UDP 53 to kube-dns
      extraPorts: [] # [{port: 5432, protocol: TCP, toCIDRs: ["10.20.0.0/16"]}]

  pdb:
    enabled: true
    minAvailable: "" # if blank, uses maxUnavailable
    maxUnavailable: "25%"

  hpa:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
    targets:
      cpu:
        enabled: true
        averageUtilization: 70
      memory:
        enabled: false
        averageUtilization: 80

  probes:
    http:
      enabled: true
      path: /healthz
      port: http
      initialDelaySeconds: 5
      periodSeconds: 10

  prometheus:
    serviceMonitor:
      enabled: false
      interval: 30s
      scrapeTimeout: 10s
      labels: {}
    podMonitor:
      enabled: false

  kyverno:
    enabled: false
    rules:
      disallow-privileged: true
      drop-all-capabilities: true
      disallow-root: true
```

---

## Security defaults explained

- **Drop all capabilities**: `capabilities.drop: ["ALL"]`
- **No privilege escalation**: `allowPrivilegeEscalation: false`
- **Read-only root**: `readOnlyRootFilesystem: true`
- **Seccomp**: `RuntimeDefault`
- **Non-root**: `runAsNonRoot: true`, plus fixed `runAsUser`, `runAsGroup`, `fsGroup` by default

  > If your image requires a different user/group, override these in your `values.yaml`.

---

## NetworkPolicy model

SecureKit emits two policies when enabled:

1. **`<release>-default-deny`**

   - Denies all **ingress** and **egress** by default.

2. **`<release>-allow-common`**

   - **Ingress**: allows **same-namespace** traffic and any namespaces/CIDRs you list.
   - **Egress**: allows **DNS** to `kube-system` (TCP/UDP 53) and any namespaces/CIDRs/ports you list.

Tuning examples:

```yaml
securekit:
  networkPolicy:
    ingress:
      allowFromNamespaces: ["ingress-nginx", "monitoring"]
      allowFromCIDRs: ["10.0.0.0/8"]
    egress:
      allowDNS: true
      extraPorts:
        - port: 5432
          protocol: TCP
          toCIDRs: ["10.20.0.0/16"]
```

---

## HPA, PDB, Probes

- **HPA** (`autoscaling/v2`): off by default. Enable and set CPU/memory targets.
- **PDB** (`policy/v1`): on by default. If `minAvailable` is blank, we use `maxUnavailable: "25%"`.

  > Ensure your label selectors match your Deployment labels (the starter already does).

- **Probes**: `securekit.probes.http` defines HTTP liveness/readiness with one block.

---

## Observability (ServiceMonitor/PodMonitor)

If you’re running Prometheus Operator, enable these and SecureKit will render the CRDs **only when they exist**:

```yaml
securekit:
  prometheus:
    serviceMonitor:
      enabled: true
      interval: 15s
      scrapeTimeout: 10s
    podMonitor:
      enabled: false
```

---

## Pod Security Admission labels

If your chart **creates a Namespace** (some charts do), you can ask SecureKit to label it for PSA:

```yaml
namespace:
  create: true
  name: my-namespace
securekit:
  podSecurityAdmission:
    enabled: true
    level: "restricted"
    version: "latest"
```

> SecureKit will **not** create a Namespace unless your chart already supports `namespace.create: true`.

---

## Kyverno optional hardening

If your cluster runs Kyverno, SecureKit can render conservative policies like:

- Disallow privileged containers
- Drop all capabilities
- Disallow root

```yaml
securekit:
  kyverno:
    enabled: true
    rules:
      disallow-privileged: true
      drop-all-capabilities: true
      disallow-root: true
```

SecureKit checks for Kyverno CRDs before emitting resources.

---

## Compatibility matrix

| Feature                   | API/CRD                    | K8s           |
| ------------------------- | -------------------------- | ------------- |
| NetworkPolicy             | `networking.k8s.io/v1`     | 1.8+          |
| PodDisruptionBudget       | `policy/v1`                | 1.21+         |
| HPA                       | `autoscaling/v2`           | 1.23+         |
| ServiceMonitor/PodMonitor | `monitoring.coreos.com/v1` | Operator CRDs |
| PSA labels                | Core (`Namespace.labels`)  | 1.25+         |
| Kyverno policies          | `kyverno.io/v1`            | Kyverno CRDs  |

---

## Troubleshooting

- **No traffic after enabling NetworkPolicy**
  Start permissive and tighten gradually:

  ```yaml
  securekit:
    networkPolicy:
      ingress:
        allowSameNamespace: true
      egress:
        allowDNS: true
        allowToNamespaces: ["kube-system"]
  ```

- **Read-only filesystem breaks the app**
  Override:

  ```yaml
  securekit:
    containerSecurityContext:
      readOnlyRootFilesystem: false
  ```

- **Probes fail**
  Ensure your container exposes a named port (default name is `http`) and the path exists:

  ```yaml
  securekit:
    probes:
      http:
        path: /healthz
        port: http
  ```

---

## Versioning & releases

- Chart version: **0.1.0**
- Tag a new release (e.g., `v0.1.1`) after bumping `version` in `helm-securekit/Chart.yaml`.
  GitHub Actions packages the chart and updates `/docs/index.yaml`.

---

## Contributing

PRs welcome! Please keep defaults **secure-by-default** and distro-agnostic. Open issues for new profiles (e.g., `strict`/`balanced`/`permissive`).

---

## Security policy

Report security issues to **[abdulazizbinhelal1@gmail.com](mailto:abdulazizbinhelal1@gmail.com)**. We’ll coordinate a fix and release.

---

## License

Apache-2.0 © Abdulaziz Alhelal
