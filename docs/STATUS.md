# Status

**Stand:** 2026-08-23

## Phasenplan
- [x] Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend) — Schritt 5 offen
- [ ] Phase 2 – VMs via OpenTofu + cloud-init
- [ ] Phase 3 – k3s-Cluster
- [ ] Phase 4 – Workloads deklarativ (Helm, Ingress, cert-manager)
- [ ] Phase 5 – GitOps (ArgoCD/Flux)
- [ ] Phase 6 – CI/CD-Pipeline
- [ ] Phase 7 – Observability (Prometheus/Grafana)
- [ ] Phase 8 – Supply-Chain & Härtung (cosign, Kyverno)
- [ ] Phase 9 – Portfolio-Finish & Zertifizierung

## Ziel
k3s-Homelab auf Proxmox, vollständig als Infrastructure as Code (OpenTofu).
Zweck: Lernen & Portfolio für die DevOps-Jobsuche. Ich tippe alle Befehle
selbst in der CLI – Schritte einzeln, Entscheidungen vor der Umsetzung erklären.

## Umgebung (Eckdaten)
- Proxmox-Host, Storage `lab`
- RustFS-State-Backend: LXC `8001`, IP `192.168.0.68`
- Tofu-Endpoint: `https://s3.marpal-it.de` (TLS via NPM), Bucket `tofu-state`
- Arbeitsverzeichnis Tofu: `infra/live/homelab/`
- Tooling gepinnt via mise (OpenTofu 1.12.6; Sops 3.13.3; age 1.3.1)

## Erledigt (Phase 1, Schritte 1–4)
- Git-Fundament: öffentliches GitHub-Repo, gitleaks + Push Protection
- Tooling: mise + OpenTofu gepinnt, pre-commit (fmt/validate)
- Secrets: SOPS + age; mise lädt sie automatisch (SOPS_AGE_KEY_FILE gesetzt)
- State-Backend: RustFS im LXC, TLS via NPM, least-privilege-S3-Key
- State-Verschlüsselung: PBKDF2, `enforced = true`; Versioning aktiv (Recovery)

## Repo-Struktur

    .
    ├── docs/
    │   ├── adr/           # Architektur-Entscheidungen (0001–0007)
    │   ├── runbooks/      # Betrieb/Reproduktion laufender Systeme
    │   └── STATUS.md      # dieser Kontext-Anker
    ├── infra/             # OpenTofu
    │   ├── modules/       # wiederverwendbare Bausteine (noch leer)
    │   └── live/homelab/  # konkrete Umgebung: backend.tf, encryption.tf,
    │                      #   variables.tf, secrets.sops.yaml (verschlüsselt)
    ├── bootstrap/         # k3s-Installation (Phase 2, noch leer)
    ├── cluster/           # k8s-/GitOps-Manifeste (Phase 5, noch leer)
    ├── mise.toml          # Tool-Versionen gepinnt
    ├── .sops.yaml         # SOPS-Regeln (öffentl. age-Key)
    └── .pre-commit-config.yaml

## Offen
- Phase 1, Schritt 5: Proxmox-API-Token (pveum-Rolle) + IP-Plan für die VMs
- Danach Phase 2: k3s-VMs via OpenTofu + cloud-init

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0007` (0002 ersetzt durch 0006)
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
