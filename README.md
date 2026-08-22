# Homelab: k3s auf Proxmox mit OpenTofu (IaC)

Ein reproduzierbares Homelab-Setup: OpenTofu provisioniert Debian-VMs auf
Proxmox VE, darauf läuft ein k3s-Cluster, auf dem Dienste deklarativ (GitOps)
ausgerollt werden. Fokus: Infrastructure as Code, saubere Secrets, CI/CD,
Observability und Supply-Chain-Härtung.

## Stack

<!-- TODO: ausfüllen, während die Phasen wachsen -->
- **IaC:** OpenTofu (Proxmox-Provider `bpg/proxmox`)
- **State:** MinIO (S3-kompatibel), native Locking, verschlüsselt
- **Secrets:** SOPS + age
- **Cluster:** k3s auf VMs
- **GitOps / CI/CD / Observability:** _folgt_

## Architektur

<!-- TODO: Diagramm einfügen (z. B. docs/architecture.png) -->
_Kommt in Phase 2/3._

## Reproduzieren

<!-- TODO: Schritt-für-Schritt, sobald die Module stehen -->
```bash
# folgt
```

## Architektur-Entscheidungen (ADRs)

Wichtige Entscheidungen sind als ADRs unter [`docs/adr/`](docs/adr/) dokumentiert
– das *Warum*, nicht nur das *Was*.

## Sicherheit

- `.gitignore` schützt State, tfvars und Keys; **erster Commit** des Repos.
- `pre-commit` + `gitleaks` blocken versehentliche Secrets lokal.
- Secrets liegen SOPS-verschlüsselt im Repo, entschlüsselt wird mit age
- GitHub Secret Scanning + Push Protection als serverseitige zweite Ebene.
- State ist verschlüsselt (OpenTofu State Encryption) und liegt nie im Repo.
