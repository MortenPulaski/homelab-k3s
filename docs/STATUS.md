# Status

**Stand:** 2026-08-25

## Phasenplan
- ✅ Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend, Proxmox-Zugang) — abgeschlossen
- ✅ Phase 2 – VMs via OpenTofu + cloud-init (Debian-Image, VM-Modul, 5-Node-Cluster) — abgeschlossen
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
- Proxmox-API-Zugang: User `tofu@pve`, Rolle `TofuRole` (in Phase 2 um die
  beim VM-Create angeforderten Rechte erweitert), Provider `bpg/proxmox`
  0.111.1 (siehe `docs/runbooks/proxmox-access.md`)
- Zweiter Provider: `hashicorp/local` (liest den öffentlichen SSH-Key für
  cloud-init) – im Lockfile gepinnt
- VM-Basis-Image: Debian 13 „Trixie" genericcloud, via `download_file` nach
  Datastore `local` gezogen; VM-Disks auf ZFS `lab`
- k3s-Nodes (statisch via cloud-init, in Phase 2 provisioniert):
  - `192.168.0.160`–`162`: Server-Nodes (embedded etcd, HA)
  - `192.168.0.163`–`164`: Agent-Nodes
  - `192.168.0.170`: kube-vip (API-Server-VIP, Phase 3)
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

## Erledigt (Phase 2)
- Cloud-Image via Tofu gezogen: `proxmox_download_file` (Content-Type
  `import`, Ziel `local`), Debian 13 genericcloud – als Code, kein manueller
  Template-Bau
- Wiederverwendbares VM-Modul `infra/modules/vm/` – natives cloud-init
  (nur API, kein SSH auf den Host), `agent { enabled = false }`; Node-Prep
  bewusst nach Phase 3 (Ansible) verschoben. Begründung: ADR-0009
- 5-Node-Topologie provisioniert: 3 Server (`.160`–`.162`) + 2 Agents
  (`.163`–`.164`) über `module` + `for_each`, statische IPs; verifiziert
  (SSH, Hostname, IP, Disk-Grow auf 20 G)
- State-Umzug der ersten (flachen) VM ins Modul via `moved`-Block – kein
  Rebuild (`0 changed, 0 destroyed`)
- Proxmox-Rolle iterativ um `Datastore.AllocateTemplate`, `VM.Config.HWType`,
  `SDN.Use` erweitert (real beim VM-Create angefordert, PVE-9-Eigenheiten) –
  Runbook fortgeschrieben
- `.gitignore` gehärtet: modul-lokale `.terraform.lock.hcl` ignoriert, die
  Root-Lockfile bleibt bewusst versioniert (Provider-Pinning, ADR-0004)

## Repo-Struktur

    .
    ├── docs/
    │   ├── adr/           # Architektur-Entscheidungen (0001–0009)
    │   ├── runbooks/      # Betrieb/Reproduktion laufender Systeme
    │   └── STATUS.md      # dieser Kontext-Anker
    ├── infra/             # OpenTofu
    │   ├── modules/
    │   │   └── vm/        # wiederverwendbares VM-Modul
    │   │                  #   (main/variables/outputs/versions.tf)
    │   └── live/homelab/  # konkrete Umgebung: backend.tf, encryption.tf,
    │                      #   variables.tf, provider.tf, image.tf,
    │                      #   k3s-nodes.tf, secrets.sops.yaml (verschlüsselt)
    ├── bootstrap/         # k3s-Installation via Ansible (Phase 3, noch leer)
    ├── cluster/           # k8s-/GitOps-Manifeste (Phase 5, noch leer)
    ├── mise.toml          # Tool-Versionen gepinnt
    ├── .sops.yaml         # SOPS-Regeln (öffentl. age-Key)
    └── .pre-commit-config.yaml

## Offen

- **Foundation-Projekt (Backlog):** RustFS-LXC + Proxmox-Zugang
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

  Phase 2 ist abgeschlossen; dieser Punkt ist damit entblockt (Priorität
  gegenüber Phase 3 noch zu wählen).

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0009` (0002 ersetzt durch 0006;
  0009 = VM-Provisioning: Cloud-Image-Import + natives cloud-init)
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
- Proxmox-Zugang: `docs/runbooks/proxmox-access.md`
