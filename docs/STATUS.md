# Status

**Stand:** 2026-08-23

## Phasenplan
- ✅ Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend, Proxmox-Zugang) — abgeschlossen
- Phase 2 – VMs via OpenTofu + cloud-init
- Phase 3 – k3s-Cluster
- Phase 4 – Workloads deklarativ (Helm, Ingress, cert-manager)
- Phase 5 – GitOps (ArgoCD/Flux)
- Phase 6 – CI/CD-Pipeline
- Phase 7 – Observability (Prometheus/Grafana)
- Phase 8 – Supply-Chain & Härtung (cosign, Kyverno)
- Phase 9 – Portfolio-Finish & Zertifizierung

## Ziel
k3s-Homelab auf Proxmox, vollständig als Infrastructure as Code (OpenTofu).
Zweck: Lernen & Portfolio für die DevOps-Jobsuche. Ich tippe alle Befehle
selbst in der CLI – Schritte einzeln, Entscheidungen vor der Umsetzung erklären.

## Umgebung (Eckdaten)
- Proxmox-Host `pve2` (i7-13700T, 64 GB RAM, ZFS-Storage), TLS via NPM
  (`pve2.marpal-it.de`)
- RustFS-State-Backend: LXC `8001`, IP `192.168.0.68`
- Tofu-Endpoint: `https://s3.marpal-it.de` (TLS via NPM), Bucket `tofu-state`
- Proxmox-API-Zugang: User `tofu@pve`, Rolle `TofuRole`, Provider
  `bpg/proxmox` 0.111.1 (siehe `docs/runbooks/proxmox-access.md`)
- k3s-IP-Plan (statisch via cloud-init, Phase 2):
  - `192.168.0.160`–`162`: Server-Nodes (embedded etcd, HA)
  - `192.168.0.163`–`164`: Agent-Nodes
  - `192.168.0.170`: kube-vip (API-Server-VIP)
  - `192.168.0.165`–`169`: Reserve
  - Begründung/Trade-off: siehe ADR-0008
- Arbeitsverzeichnis Tofu: `infra/live/homelab/`
- Tooling gepinnt via mise (OpenTofu 1.12.6; Sops 3.13.3; age 1.3.1)

## Erledigt (Phase 1, Schritte 1–5)
- Git-Fundament: öffentliches GitHub-Repo, gitleaks + Push Protection
- Tooling: mise + OpenTofu gepinnt, pre-commit (fmt/validate)
- Secrets: SOPS + age; mise lädt sie automatisch (SOPS_AGE_KEY_FILE gesetzt)
- State-Backend: RustFS im LXC, TLS via NPM, least-privilege-S3-Key
- State-Verschlüsselung: PBKDF2, `enforced = true`; Versioning aktiv (Recovery)
- Proxmox-Zugang: dediziertes User/Rolle/Token (least-privilege), Provider
  konfiguriert und verifiziert (`tofu plan` erfolgreich), siehe
  `docs/runbooks/proxmox-access.md`
- k3s-Cluster-Design: HA-Topologie (3 Server + 2 Agents) + IP-Plan
  festgelegt, Trade-off dokumentiert in ADR-0008

## Repo-Struktur

    .
    ├── docs/
    │   ├── adr/           # Architektur-Entscheidungen (0001–0008)
    │   ├── runbooks/      # Betrieb/Reproduktion laufender Systeme
    │   └── STATUS.md      # dieser Kontext-Anker
    ├── infra/             # OpenTofu
    │   ├── modules/       # wiederverwendbare Bausteine (noch leer)
    │   └── live/homelab/  # konkrete Umgebung: backend.tf, encryption.tf,
    │                      #   variables.tf, provider.tf, secrets.sops.yaml
    │                      #   (verschlüsselt)
    ├── bootstrap/         # k3s-Installation (Phase 2, noch leer)
    ├── cluster/           # k8s-/GitOps-Manifeste (Phase 5, noch leer)
    ├── mise.toml          # Tool-Versionen gepinnt
    ├── .sops.yaml         # SOPS-Regeln (öffentl. age-Key)
    └── .pre-commit-config.yaml

## Offen

- **Foundation-Projekt (Backlog, nach Phase 2):** RustFS-LXC + Proxmox-Zugang
  (`tofu@pve`) als eigenes, getrenntes Tofu-Projekt `foundation/` codifizieren
  (Bootstrap-Stack-Muster, eigener lokaler PBKDF2-State, gitignored, Backup
  im Passwortmanager – kein Zirkelbezug zu ADR-0006).

  **Vorab-Check (5 Min., potenzieller Blocker):** `pct config 8001` prüfen –
  `unprivileged` und `features`. Feature-Flags außer `nesting` lassen sich
  nur als root@pam ändern; ändert die Ausgangslage für den ganzen Plan.

  **RustFS-LXC:** Import. Risiko: erster `plan` kann `forces replacement`
  zeigen (nicht importierbare Pflichtattribute wie
  `operating_system.template_file_id`, `initialization`). Protokoll:
  ZFS-Snapshot → `tofu state pull` sichern → importieren → `plan` prüfen →
  jedes `forces replacement` = Stopp, HCL angleichen oder `ignore_changes`.
  Fertig erst bei `No changes`.

  **`tofu@pve`/`TofuRole`/Token:** Neuanlage nötig (Token-Secret beim Import
  nicht abrufbar). Cutover-Reihenfolge: neues Token erzeugen → SOPS in
  `infra/live/homelab/secrets.sops.yaml` aktualisieren → `tofu plan` im
  Homelab-Projekt verifizieren → erst dann altes Token löschen. Reihenfolge
  zwingend einhalten, sonst Aussperrung aus dem Hauptprojekt.

  **Auth-Henne-Ei:** Kein fein zugeschnittenes Custom-Bootstrap-Token
  (Over-Engineering für eine Identität, die Minuten lebt – Provider-Doku
  kennt zudem Fälle, wo privilegierte Operationen selbst mit
  Administrator-Rolle per API-Token scheitern). Stattdessen: **ephemeres
  root@pam-Token**, vor dem Lauf erzeugt, danach gelöscht. Sicherheitsmerkmal
  ist die Kurzlebigkeit, nicht der Privilegienzuschnitt.

  **Scope-Grenze:** Codifiziert wird nur die Container-Hülle, nicht der
  RustFS-Dienst selbst (Installation, TLS, Bucket, S3-Key bleiben Runbook).
  NPM, DNS und Proxmox-Host-Konfig bleiben ebenfalls außen vor.

  **Aufwand:** ~5–7 Std. inkl. eigenem ADR (LXC-Import mit
  Sicherheits-Protokoll: 3–4 Std.; Proxmox-IAM-Teil: 2–3 Std.).

  Bewusst zurückgestellt: Phase 2 hat Priorität (erste echte VM vor
  vierter Fundament-Aufgabe).

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0008` (0002 ersetzt durch 0006)
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
- Proxmox-Zugang: `docs/runbooks/proxmox-access.md`
