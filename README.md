# Helm SecureKit

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helm-securekit)](https://artifacthub.io/packages/search?repo=helm-securekit)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

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
- [Quickstart](#quickstart)
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

- **Fast**: one dependency, a few helper includes  
- **Portable**: uses GA Kubernetes APIs; extras are gated behind feature flags  
- **Composable**: you keep your chart’s structure and simply include SecureKit helpers  

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
````

---

## Quickstart

Try the starter app wired with SecureKit:

```bash
helm create demo --starter securekit-app
helm install demo ./demo
```

This deploys a simple HTTP server with:

* Default-deny NetworkPolicies
* Read-only root filesystem
* Probes enabled at `/healthz`
* A PodDisruptionBudget

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

---

## Example: Before & After

**Without SecureKit:**

```yaml
containers:
  - name: app
    image: myapp:1.0
```

**With SecureKit:**

```yaml
containers:
  - name: app
    image: myapp:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop: ["ALL"]
```

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

* `NetworkPolicy` (default-deny + allow rules)
* `PodDisruptionBudget`
* `HorizontalPodAutoscaler`
* (Optional) `ServiceMonitor` and/or `PodMonitor` (if CRDs exist)
* (Optional) `Namespace` with Pod Security Admission (PSA) labels when your chart creates a namespace

Plus **helpers** you include in your own resources:

* `securekit.labels`
* `securekit.podSecurityContext`
* `securekit.containerSecurityContext`
* `securekit.probes.http`

---

## Values reference

*(same as your current section — unchanged for brevity)*

---

## Security defaults explained

* Drop all Linux capabilities
* No privilege escalation
* Read-only root filesystem
* RuntimeDefault seccomp
* Run as non-root UID/GID

---

## NetworkPolicy model

* **`<release>-default-deny`**: denies all ingress & egress
* **`<release>-allow-common`**: allows same-namespace + configured namespaces/CIDRs + DNS if enabled

---

## HPA, PDB, Probes

* **HPA**: off by default, enable in values
* **PDB**: on by default, ensures at least 75% availability
* **Probes**: liveness/readiness via `securekit.probes.http`

---

## Observability

Enable ServiceMonitor/PodMonitor if running Prometheus Operator. SecureKit emits them only if CRDs are present.

---

## Pod Security Admission labels

If your chart creates a Namespace, SecureKit can label it with PSA level (`restricted` by default).

---

## Kyverno optional hardening

If Kyverno is installed, SecureKit can add conservative policies (no privileged, drop all caps, no root).

---

## Compatibility matrix

| Feature                     | API / CRD                  | Min K8s |
| --------------------------- | -------------------------- | ------- |
| NetworkPolicy               | `networking.k8s.io/v1`     | 1.8+    |
| PodDisruptionBudget         | `policy/v1`                | 1.21+   |
| HPA                         | `autoscaling/v2`           | 1.23+   |
| ServiceMonitor / PodMonitor | `monitoring.coreos.com/v1` | CRDs    |
| PSA labels                  | Core API                   | 1.25+   |
| Kyverno policies            | `kyverno.io/v1`            | CRDs    |

---

## Troubleshooting

* **All traffic blocked?** → adjust `allowFromNamespaces`, `allowDNS`
* **App fails with read-only FS?** → set `securekit.containerSecurityContext.readOnlyRootFilesystem: false`
* **Probes failing?** → ensure container exposes `http` port and health path

---

## Versioning & releases

* Current version: **0.1.0**
* Tag `vX.Y.Z` to release. GitHub Actions packages chart, updates `/docs`, and creates release.

---

## License

Apache-2.0 © Abdulaziz Alhelal
