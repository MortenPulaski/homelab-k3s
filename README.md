# Homelab: k3s auf Proxmox mit OpenTofu (IaC)

> Kurzbeschreibung in 2-3 Sätzen: Was ist das, wofür gebaut, was zeigt es.
> (Deine Worte – das ist der erste Absatz, den ein Recruiter liest.)

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
- GitHub Secret Scanning + Push Protection als serverseitige zweite Ebene.
- State ist verschlüsselt (OpenTofu State Encryption) und liegt nie im Repo.
