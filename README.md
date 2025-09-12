# Helm SecureKit (library chart)

Security, resilience, and observability **building blocks** for any Helm chart. Add one dependency and get:
- Default-deny **NetworkPolicies** (with DNS egress)
- Sensible **securityContexts** (drops ALL capabilities, RuntimeDefault seccomp, runAsNonRoot)
- **PodDisruptionBudget**
- Optional **HPA**
- HTTP **probes**
- Optional **ServiceMonitor/PodMonitor**
- Optional **Pod Security** namespace labels (PSA)

## Quickstart

```bash
helm repo add helm-securekit https://azizhilal.github.io/helm-securekit
helm repo update
```

Add as a dependency in your chart:
```yaml
# Chart.yaml
dependencies:
  - name: helm-securekit
    version: 0.1.0
    repository: "https://azizhilal.github.io/helm-securekit"
```

Use helpers in your Deployment:
```gotemplate
spec:
  template:
    spec:
      securityContext:
        {- include "securekit.podSecurityContext" . | nindent 8 }
      containers:
        - name: myapp
          securityContext:
            {- include "securekit.containerSecurityContext" . | nindent 12 }
          {- include "securekit.probes.http" . | nindent 10 }
```

### Starter
```bash
helm create myapp --starter securekit-app
```

## Requirements
- Kubernetes **>=1.25**

## Publishing (maintainer notes)
1. Enable **GitHub Pages** → `/docs`.
2. Create a release tag `v0.1.0`. GitHub Actions will:
   - package the chart (`.tgz`)
   - update `/docs/index.yaml`
3. Register the repo on **Artifact Hub**.

## License
Apache-2.0 © Abdulaziz Alhelal
