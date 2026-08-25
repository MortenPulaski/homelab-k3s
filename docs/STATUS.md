# Status

**Stand:** 2026-08-25

## Phasenplan
- ✅ Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend, Proxmox-Zugang) — abgeschlossen
- ✅ Phase 2 – VMs via OpenTofu + cloud-init (Debian-Image, VM-Modul, 5-Node-Cluster) — abgeschlossen
- 🔄 Phase 3 – k3s-Cluster — in Arbeit (Node-Prep + Guest-Agent erledigt; k3s-Install als Nächstes)
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
- cloud-init-User auf den Nodes: `ops` (NOPASSWD-sudo)
- Arbeitsverzeichnis Tofu: `infra/live/homelab/`
- Arbeitsverzeichnis Ansible: `bootstrap/`
- Tooling gepinnt via mise (OpenTofu 1.12.6; Sops 3.13.3; age 1.3.1;
  Ansible 14.3.1; pipx 1.16.7). kubectl folgt zu Beginn des k3s-Installs.

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

## Erledigt (Phase 3 – bisher)
- Ansible-Tooling gepinnt: `ansible` 14.3.1 (pipx-Backend, `--include-deps`)
  + `pipx` 1.16.7 (aqua) in `mise.toml`. Pin-Politik als ADR-0004-Nachtrag
  festgehalten: ergebnis-bestimmende Tools exakt pinnen, Komfort-Tools
  (`github-cli`) dürfen `latest` sein
- `bootstrap/`-Fundament: `ansible.cfg` (become via NOPASSWD-sudo als `ops`,
  host key checking an, YAML-Ausgabe über den built-in default-Callback +
  `callback_result_format`), YAML-Inventory (Gruppen `k3s_servers` /
  `k3s_agents` nach ADR-0008); Connectivity mit `ansible all -m ping`
  verifiziert
- `prep`-Rolle (Phase 3a): installiert `qemu-guest-agent`, `btop`, `curl`;
  Zeitzone `Europe/Berlin`; `systemd-timesyncd` für Zeitsync; Swap-Deaktivierung
  nur falls vorhanden (Cloud-Image hat keinen → Tasks skippen). Idempotent auf
  allen 5 Nodes verifiziert (`changed=0` im zweiten Lauf). qemu-guest-agent
  wird von Ansible NICHT gestartet: die Unit ist `BindsTo` das virtio-serial-
  Device und startet selbst, sobald der Kanal da ist
- Guest-Agent-Kanal aktiviert (Phase 3b): `agent_enabled` als Root-Variable
  (`live`-Default true) → Modul-Variable (Default false) → `agent { enabled }`.
  In-place-Flip false→true auf allen 5 Nodes; Provider rebootet selbst
  (`reboot_after_update`). Agent aktiv, Proxmox meldet die Node-IPs. Zweistufiger
  Bring-up dokumentiert im ADR-0009-Nachtrag (belegt via dpkg.log: das
  genericcloud-Image bringt qemu-guest-agent nicht mit)

## Nächster Schritt (Phase 3 – k3s-Install)
Entscheidungen zuerst, dann Befehle:
- k3s-Version festlegen und pinnen (aktuelle stable prüfen)
- kubectl in `mise.toml` pinnen (Version-Skew zur k3s-Version)
- erster Server mit `--cluster-init` (embedded etcd), dann Server 2/3 + Agents
- Cluster-Token als SOPS-Secret
- kube-vip als API-Server-VIP (`192.168.0.170`, ARP-Modus)
- eigenes Ansible-Playbook (Weg A) → am Ende ADR-0010 (Config-Management)

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
    ├── bootstrap/         # k3s-Installation via Ansible
    │   ├── ansible.cfg
    │   ├── inventory/hosts.yml
    │   ├── group_vars/    # all.yml (Platzhalter, füllt sich im k3s-Install)
    │   ├── roles/
    │   │   └── prep/      # Node-Vorbereitung (Phase 3a)
    │   └── site.yml       # Haupt-Playbook
    ├── cluster/           # k8s-/GitOps-Manifeste (Phase 5, noch leer)
    ├── mise.toml          # Tool-Versionen gepinnt
    ├── .sops.yaml         # SOPS-Regeln (öffentl. age-Key)
    └── .pre-commit-config.yaml

## Offen

- **Foundation-Projekt (Backlog):** RustFS-LXC + Proxmox-Zugang
  (`tofu@pve`) als eigenes, getrenntes Tofu-Projekt `foundation/` codifizieren
  (Bootstrap-Stack-Muster, eigener lokaler PBKDF2-State, gitignored, Backup
  im Passwortmanager – kein Zirkelbezug zu ADR-0006). Details/Protokoll unten.
  Priorität gegenüber Phase 3 offen gelassen; Phase 3 wurde zuerst gestartet.

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

  **Auth-Henne-Ei:** ephemeres root@pam-Token, vor dem Lauf erzeugt, danach
  gelöscht. Sicherheitsmerkmal ist die Kurzlebigkeit, nicht der
  Privilegienzuschnitt.

  **Scope-Grenze:** Codifiziert wird nur die Container-Hülle, nicht der
  RustFS-Dienst selbst (Installation, TLS, Bucket, S3-Key bleiben Runbook).
  NPM, DNS und Proxmox-Host-Konfig bleiben ebenfalls außen vor.

  **Aufwand:** ~5–7 Std. inkl. eigenem ADR.

- **ADR-0010 (geplant):** Config-Management mit Ansible (eigenes Playbook,
  Werkzeug-Grenze Tofu/Ansible) – schreiben, wenn der k3s-Install steht.

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0009` (0002 ersetzt durch 0006;
  0004 + 0009 mit Nachträgen vom 2026-08-25; 0009 = VM-Provisioning:
  Cloud-Image-Import + natives cloud-init)
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
- Proxmox-Zugang: `docs/runbooks/proxmox-access.md`
