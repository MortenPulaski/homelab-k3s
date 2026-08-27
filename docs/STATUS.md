# Status

**Stand:** 2026-08-27

## Phasenplan
- ✅ Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend, Proxmox-Zugang) — abgeschlossen
- ✅ Phase 2 – VMs via OpenTofu + cloud-init (Debian-Image, VM-Modul, 5-Node-Cluster) — abgeschlossen
- ✅ Phase 3 – k3s-Cluster — abgeschlossen (Basis-Cluster aus 3 Servern + 2 Agents läuft und verifiziert; kube-vip als HA-API-VIP aktiv, Failover verifiziert; zwei Zwischen-Incidents dokumentiert in `docs/incidents/incidents.md`; ADR-0010 geschrieben)
- 🔄 Phase 4 – Workloads deklarativ (Helm, Ingress, cert-manager) — gestartet: Ingress-Entscheidung (Traefik/Klipper beibehalten) + Deploy-Mechanismus (k3s HelmChart-CRD) getroffen, cert-manager installiert
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
- `on_boot = false` für alle 5 k3s-Nodes (`infra/modules/vm/`, Modul-Default) –
  kein Autostart bei Proxmox-Host-Reboot, bewusst gegen Dauerlast im
  Lern-/Portfolio-Betrieb (Umschaltmechanismus analog zu `agent_enabled`,
  falls später Dauerbetrieb gewünscht)
- k3s-Nodes (statisch via cloud-init, in Phase 2 provisioniert):
  - `192.168.0.160`–`162`: Server-Nodes (embedded etcd, HA) – **läuft**
  - `192.168.0.163`–`164`: Agent-Nodes – **läuft**
  - `192.168.0.170`: kube-vip (API-Server-VIP) – **aktiv, Failover verifiziert**
    (siehe „Erledigt (Phase 3)")
  - `192.168.0.165`–`169`: Reserve
  - Begründung/Trade-off: siehe ADR-0008
- k3s-Version: `v1.36.3+k3s1` (aktuellster Stable, Kubernetes 1.36.3,
  etcd 3.6.14 – Downgrade-Einbahnstraße für spätere Upgrades bewusst
  akzeptiert, siehe Entscheidungsverlauf im Chat vom 2026-08-26)
- Cluster-Join-Token: `K3S_TOKEN` in `secrets.sops.yaml`, vorab selbst
  generiert (`openssl rand -hex 32`), nicht von k3s auto-generiert –
  Ansible zieht ihn per `lookup('env', 'K3S_TOKEN')`
- cloud-init-User auf den Nodes: `ops` (NOPASSWD-sudo)
- Arbeitsverzeichnis Tofu: `infra/live/homelab/`
- Arbeitsverzeichnis Ansible: `bootstrap/`
- Tooling gepinnt via mise (OpenTofu 1.12.6; Sops 3.13.3; age 1.3.1;
  Ansible 14.3.1; pipx 1.16.7; **kubectl 1.36.3**, passend zur k3s-Version)
- Commit-Konvention: Commit-Messages ab sofort auf Englisch (frühere deutsche
  Messages der k3s-Bootstrap-Serie per interaktivem Rebase nachträglich
  übersetzt)

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
- `on_boot = false` als Modul-Default ergänzt (siehe Umgebung oben)

## Erledigt (Phase 3)
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
- k3s-Version festgelegt: `v1.36.3+k3s1`; kubectl 1.36.3 passend via mise gepinnt
- Cluster-Token vorab generiert (`openssl rand -hex 32`) statt k3s-auto-generiert
  – reproduzierbar, kein Rückkanal von Server-1 nötig
- Ansible-Rollenstruktur: `k3s_server` (cluster-init auf srv-1 via
  `k3s_primary`-Flag in `hosts.yml`, Join für srv-2/3) + `k3s_agent` (Join
  gegen Server-1) – zwei Rollen statt drei, da sich die Server-Varianten fast
  alle Tasks teilen
- `site.yml`: Plays (prep → srv-1 → restliche Server → Agents →
  kube-vip-Rolling-Restart), mit `tags: [prep]` / `tags: [k3s]` /
  `tags: [kube-vip-restart]` versehen; Server-1 bewusst als eigener Play
  (nicht `serial`), um unterschiedliche Rollen-Zweige sauber zu trennen.
  Grund fürs Tagging: siehe „Reproduzierbarer Node-Bring-up" unten
- **Basis-Cluster live verifiziert:** 3 Server (`control-plane,etcd`) + 2
  Agents, alle `Ready`, `v1.36.3+k3s1`, korrekte IPs
- **`tls-san` für kube-vip-VIP:** `roles/k3s_server/templates/config.yaml.j2`
  (`tls-san: 192.168.0.170`) + Template-Task in `roles/k3s_server/tasks/main.yml`,
  bewusst VOR dem Install-Task (Von-Null-Neubau hat die VIP von Anfang an im
  Zertifikat, kein nachträglicher Restart nötig). Für den Nachrüst-Fall auf
  bereits laufenden Servern zusätzlich Rolling-Restart-Play in `site.yml`
  (Tag `kube-vip-restart`, `serial: 1`, `wait_for` auf Port 6443 zwischen den
  Nodes – etcd-Quorum-sicher). Verifiziert per `openssl s_client`: API-Server-
  Zertifikat enthält `192.168.0.170` als SAN.
- **kube-vip nachgerüstet und verifiziert (2026-08-27):** RBAC + DaemonSet
  (`v1.2.0`, `cluster/kube-vip/`) per `kubectl apply` gegen den laufenden
  Cluster angewendet. Zwei Zwischen-Incidents dabei aufgetreten und behoben –
  vollständige Root-Cause-Analyse in `docs/incidents/incidents.md`
  (INC-001, INC-002). Finaler Zustand: `svc_enable: "false"` (kube-vip nur
  für die API-Server-VIP zuständig, nicht für `Service type=LoadBalancer` –
  vermeidet Konflikt mit k3s' eingebautem ServiceLB/Klipper) + `nodeSelector:
  node-role.kubernetes.io/control-plane: "true"` (DaemonSet läuft nur auf den
  3 Server-Nodes, nicht auf den Agents).
  **Verifiziert:** VIP (`192.168.0.170`) sitzt nach Leader-Election auf genau
  einem Server-Node, `kubectl --server=https://192.168.0.170:6443` funktioniert;
  kontrollierter Cluster-Reboot überstanden; harter Node-Ausfall simuliert
  (`qm stop` auf dem VIP-Leader) → Failover zu neuem Leader in wenigen
  Sekunden, VIP-Zugriff durchgehend funktionsfähig, Node-Rejoin sauber
  (`/healthz` → `ok`). **Phase-3-Kernziel (HA-API-VIP) damit erreicht.**

### Nachtrag (2026-08-26): Kontrollierter Cluster-Shutdown + Proxmox-Startreihenfolge

- **`bootstrap/shutdown.yml`** (neues, separates Playbook, nicht Teil von
  `site.yml`): drei sequenzielle Plays – erst `k3s-agent` auf den Agents
  stoppen, dann `k3s` auf den Servern, zuletzt alle Nodes per
  `community.general.shutdown` herunterfahren. Reihenfolge Agents-vor-Server
  ist beim gemeinsamen Shutdown nicht quorum-kritisch (alle 3 Server gehen
  gleichzeitig runter, siehe ADR-0008), dient aber saubereren Logs und
  spiegelt die Startreihenfolge.
- **Proxmox Start/Shutdown-Reihenfolge jetzt via Tofu codifiziert**
  (`infra/modules/vm/`, neue optionale Variablen `startup_order` /
  `startup_up_delay`, `dynamic "startup"`-Block): Server-Nodes
  `order = 1, up_delay = 10`, Agent-Nodes `order = 2`. Wert nach
  Massenstart-Test per journalctl-Zeitstempel-Vergleich verifiziert
  (Server registrieren sich untereinander deutlich innerhalb von 10s). Grund: Agents
  brauchen beim Boot einen erreichbaren API-Server; ohne definierte
  Reihenfolge (`any`, Proxmox-Default) starten alle 5 VMs beim
  UI-Massenstart parallel. Damit ist ein einzelner Massenstart aller
  5 VMs in der Proxmox-UI sicher möglich, ohne die Agents manuell
  zeitversetzt zu starten.
- `down_delay` bewusst nicht gesetzt (Provider-Default `-1`/kein Delay) –
  der Shutdown-Pfad läuft über das Ansible-Playbook oben, nicht über
  Proxmox' eigenen Shutdown-Mechanismus.
- Erfolgreich genutzt, um den harten Node-Ausfall-Test für kube-vip
  durchzuführen (siehe „Erledigt (Phase 3)" oben) – Massenstart nach
  Von-Null-Neubau und Reboot-Test liefen darüber.

## Erledigt (Phase 4)

- **Ingress-Entscheidung:** Traefik (k3s-Default, via Klipper/ServiceLB) bleibt bestehen – kein Wechsel zu ingress-nginx. Kein Wiederholungsrisiko zu INC-002: kube-vip ist seit `svc_enable: "false"` ausschließlich für die API-VIP zuständig, rührt keine `LoadBalancer`-Services mehr an; die offene Frage aus Phase 3 (Klipper vs. MetalLB vs. kube-vip `--services`) bleibt unverändert vertagt (siehe „Offen" unten).
- **Deploy-Mechanismus für Workloads:** k3s HelmChart-CRD (`apiVersion: helm.cattle.io/v1`, `kind: HelmChart`) statt helm-CLI – konsistent mit der Werkzeuggrenze aus ADR-0010 (alles innerhalb der Kubernetes-API läuft über `kubectl apply`/CRs, kein zusätzliches externes Tool auf der Workstation). Kein neuer mise-Pin nötig.
- **cert-manager installiert:** v1.21.1 via `cluster/cert-manager/helmchart.yaml` (HelmChart-CRD, `targetNamespace: cert-manager`, `crds.enabled: true`). Verifiziert: alle drei Pods (`cert-manager`, `cainjector`, `webhook`) `Running`, alle CRDs (`Certificate`, `Issuer`, `ClusterIssuer`, ACME `Challenge`/`Order`) vorhanden.
- **TLS-Konzept festgelegt:** Wildcard-Zertifikat für `*.k3s.marpal-it.de` (ein `ClusterIssuer`, deckt alle künftigen Apps unter diesem Schema ab), DNS-01-Challenge über den DNS-Provider **netcup** via Community-Webhook (`cert-manager-webhook-netcup`, kein nativer cert-manager-Support für netcup). Bewusster Trade-off: Fremdabhängigkeit von einem Community-Repo (Einzelmaintainer) statt offiziellem Provider-Support.

### Nachtrag (2026-08-27): DNS-Search-Domain-Bug in Pods (ndots + Split-Horizon-Wildcard)

Beim ersten HelmChart-Install (cert-manager) schlug `helm repo add` mit `tls: unrecognized name` fehl. Root Cause: Kubernetes übernimmt automatisch die Search-Domain des Node-`/etc/resolv.conf` (`search marpal-it.de`, aus `dns_domain` in `infra/modules/vm/`) in jeden Pod. Bei `ndots:5` (Pod-Standard) probiert der Resolver externe Hostnamen mit weniger als 5 Punkten (z. B. `charts.jetstack.io`) zuerst mit angehängter Search-Domain (`charts.jetstack.io.marpal-it.de`) – und AdGuards Wildcard-Rewrite (`*.marpal-it.de → 192.168.0.118`, NPM) fängt genau diesen Fehlversuch ab, bevor der Resolver den korrekten, absoluten Namen probiert.

**Provider-Eigenheit (`bpg/proxmox`, bekannter Bug, Issue [#2011](https://github.com/bpg/terraform-provider-proxmox/issues/2011)):** Weder `domain = null` noch das komplette Weglassen des Attributs löschen das Feld tatsächlich in Proxmox – der Provider behandelt es als „nicht verwaltet", nicht als „leeren". Ohne explizites Attribut fällt Proxmox auf die **Node-Default-Domain** zurück (bei uns `fritz.box`, vom Router per DHCP an `pve2` vergeben), nicht auf leer. Der einzige Wert, der bei der Proxmox-API tatsächlich als „leer" ankommt, ist ein **Leerzeichen** (`" "`), kein echter Leerstring (`""`). Verifiziert per `qm config <vmid> | grep search` und `tofu plan` (`No changes` erst nach `default = " "`).

**Endgültiger Code-Stand** (`infra/modules/vm/variables.tf`):
```hcl
variable "dns_domain" {
  type    = string
  default = " "  # bewusst ein Leerzeichen, kein leerer String – Workaround für bpg/proxmox #2011
}
```

**Betroffen:** alle 5 Nodes, nachträglich per `qm set <vmid> --searchdomain ''` + `qm cloudinit update <vmid>` + `cloud-init clean --logs && reboot` gefixt (Server-Nodes seriell, Quorum währenddessen verifiziert per `kubectl get nodes` + kube-vip-Pod-Status). Bei einem Von-Null-Neubau greift jetzt der Code-Fix automatisch (`tofu plan` bestätigt `No changes` gegen den aktuellen Proxmox-Zustand).

**Nebenbefund:** `cloud-init clean` erzeugt beim nächsten Boot neue SSH-Host-Keys (cloud-init behandelt sie wie andere einmalig generierte Artefakte) – SSH meldet dann berechtigt eine Host-Key-Warnung; alten Eintrag per `ssh-keygen -R <ip>` entfernen.

## Reproduzierbarer Node-Bring-up (Neuaufbau von Null)

Der Recovery-Weg lief zunächst nur, weil die Befehle manuell in der
richtigen Reihenfolge eingegeben wurden – das Playbook selbst erzwang nichts.
Seit dem `site.yml`-Tagging (`prep` / `k3s`) ist die Reihenfolge nicht mehr
von der manuellen Befehlsfolge abhängig, sondern strukturell erzwungen:

```bash
tofu destroy
tofu apply -var agent_enabled=false   # VMs ohne Guest-Agent-Kanal (ADR-0009)
ansible-playbook site.yml --tags prep # Guest-Agent-Paket + Hygiene, noch kein k3s
tofu apply                            # Kanal aktivieren, EIN Reboot – vor k3s, nicht danach
ansible-playbook site.yml --tags k3s  # erst jetzt k3s_server + k3s_agent (inkl. tls-san)
kubectl apply -f cluster/kube-vip/rbac.yaml
kubectl apply -f cluster/kube-vip/daemonset.yaml
```

**Warum die Trennung von `agent_enabled` zwingend ist:** Der zweite
`tofu apply` rebootet die VMs (`reboot_after_update`). Liefe k3s zu dem
Zeitpunkt schon, würde OpenTofu einen laufenden etcd-Cluster unkontrolliert
(nicht `serial`, keine Ansible-Reihenfolge) neu starten – unnötiges Risiko.

*(Wandert nach Phase-3-Abschluss als finale Fassung in die README unter
„Reproduzieren" – siehe TODO dort.)*

## Repo-Struktur

    .
    ├── docs/
    │   ├── adr/           # Architektur-Entscheidungen (0001–0010)
    │   ├── incidents/      # Incident-Log (Root-Cause-Analysen, siehe incidents.md)
    │   ├── runbooks/      # Betrieb/Reproduktion laufender Systeme
    │   └── STATUS.md      # dieser Kontext-Anker
    ├── infra/             # OpenTofu
    │   ├── modules/
    │   │   └── vm/        # wiederverwendbares VM-Modul (inkl. on_boot, startup_order)
    │   │                  #   (main/variables/outputs/versions.tf)
    │   └── live/homelab/  # konkrete Umgebung: backend.tf, encryption.tf,
    │                      #   variables.tf, provider.tf, image.tf,
    │                      #   k3s-nodes.tf, secrets.sops.yaml (verschlüsselt)
    ├── bootstrap/         # k3s-Installation via Ansible
    │   ├── ansible.cfg
    │   ├── inventory/hosts.yml       # k3s_primary-Flag bei srv-1
    │   ├── group_vars/all.yml        # k3s_token, k3s_version, kube_vip_*
    │   ├── roles/
    │   │   ├── prep/                 # Node-Vorbereitung (Phase 3a)
    │   │   ├── k3s_server/           # cluster-init / Join / tls-san (Server)
    │   │   └── k3s_agent/            # Join (Agent)
    │   ├── site.yml                  # Haupt-Playbook, Tags prep/k3s/kube-vip-restart
    │   └── shutdown.yml               # Kontrollierter Cluster-Shutdown
    ├── cluster/           # k8s-Manifeste
    │   ├── kube-vip/      # RBAC + DaemonSet (Phase 3, HA-API-VIP)
    │   └── cert-manager/  # HelmChart-CRD (Phase 4, TLS-Fundament)
    ├── mise.toml          # Tool-Versionen gepinnt (inkl. kubectl 1.36.3)
    ├── .sops.yaml         # SOPS-Regeln (öffentl. age-Key)
    └── .pre-commit-config.yaml

## Offen

- **cert-manager DNS-01 / netcup-Webhook (Phase 4, in Arbeit):** netcup-API-Zugangsdaten
  (Kundennummer, API-Key, API-Passwort) aus dem CCP besorgen und in den Cluster bringen
  (Kubernetes-Secret im `cert-manager`-Namespace – Ablageweg SOPS+`kubectl` vs. direktes
  `kubectl create secret` noch zu entscheiden), `cert-manager-webhook-netcup`
  per HelmChart-CRD installieren, `ClusterIssuer` für `*.k3s.marpal-it.de`
  (DNS-01) anlegen, mit einer Test-App verifizieren.

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

- **Traefik-LoadBalancer-Zuständigkeit (Phase 4):** Aktuell bedient k3s'
  eingebautes ServiceLB (Klipper) den Traefik-Service, kube-vip ist bewusst
  nur für die Control-Plane-VIP zuständig (siehe INC-002). Endgültige
  Entscheidung (Klipper beibehalten vs. MetalLB vs. kube-vip `--services`
  erneut mit Fix) steht zusammen mit dem Ingress-Konzept in Phase 4 an.

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0010` (0002 ersetzt durch 0006;
  0004 + 0009 mit Nachträgen vom 2026-08-25; 0009 = VM-Provisioning:
  Cloud-Image-Import + natives cloud-init; 0010 = Config-Management-
  Werkzeuggrenze + kube-vip-Installationsmuster, inkl. Lessons-Learned aus
  `docs/incidents/incidents.md`)
- Incident-Log (Root-Cause-Analysen zu Betriebsstörungen):
  `docs/incidents/incidents.md`
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
- Proxmox-Zugang: `docs/runbooks/proxmox-access.md`
