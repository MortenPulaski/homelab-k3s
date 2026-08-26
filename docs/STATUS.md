# Status

**Stand:** 2026-08-26

## Phasenplan
- ✅ Phase 1 – Fundament & Setup (Git, Tooling, Secrets, State-Backend, Proxmox-Zugang) — abgeschlossen
- ✅ Phase 2 – VMs via OpenTofu + cloud-init (Debian-Image, VM-Modul, 5-Node-Cluster) — abgeschlossen
- 🔄 Phase 3 – k3s-Cluster — in Arbeit (Basis-Cluster aus 3 Servern + 2 Agents läuft und verifiziert; kube-vip als HA-API-VIP noch offen, siehe Nachtrag)
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
  - `192.168.0.170`: kube-vip (API-Server-VIP) – **noch nicht aktiv**, siehe
    Nachtrag unten
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
- `site.yml`: 4 Plays (prep → srv-1 → restliche Server → Agents), zusätzlich
  mit `tags: [prep]` / `tags: [k3s]` versehen; Server-1 bewusst als eigener
  Play (nicht `serial`), um unterschiedliche Rollen-Zweige sauber zu trennen.
  Grund fürs Tagging: siehe „Reproduzierbarer Node-Bring-up" unten
- **Basis-Cluster live verifiziert:** 3 Server (`control-plane,etcd`) + 2
  Agents, alle `Ready`, `v1.36.3+k3s1`, korrekte IPs

### Nachtrag (2026-08-26): kube-vip als Boot-Zeit-Manifest gescheitert

Erster Versuch: kube-vip-RBAC + DaemonSet-Manifest vor `--cluster-init` nach
`/var/lib/rancher/k3s/server/manifests/` kopiert (offizielles k3s+kube-vip-
Muster, DaemonSet statt kubeadm-Static-Pod). Ergebnis: Nach einigen Stunden
Laufzeit verlor `srv-1` intermittierend seine **eigene** IPv4-Adresse (nicht
nur die VIP) – Cluster über IPv4 unerreichbar, K8s-API antwortete zeitweise
gar nicht mehr (`ServiceUnavailable`). Ursache nicht abschließend verifiziert
(Verdacht: `hostNetwork: true` + `NET_ADMIN`-Capability des kube-vip-Pods in
Kombination mit dynamischer Interface-Erkennung), aber reproduzierbar mit dem
Boot-Zeit-Manifest, verschwunden nach komplettem Neuaufbau ohne kube-vip
(30+ min stabile IPv4/SSH-Verbindung bestätigt).

**Entscheidung:** kube-vip wird nicht mehr als Boot-Zeit-Manifest installiert,
sondern nachträglich per `kubectl apply` gegen den laufenden Cluster –
beobachtbar, mit Pod-Status/Logs live statt unsichtbar beim ersten Boot.
`--tls-san` muss dafür nachträglich per `/etc/rancher/k3s/config.yaml` +
Rolling-Restart (`serial: 1`, ein Server nach dem anderen wegen etcd-Quorum)
auf allen 3 Servern ergänzt werden. **Noch nicht umgesetzt** – nächster Schritt.

**Recovery-Weg, der funktioniert hat:** `tofu destroy` + `tofu apply -var
agent_enabled=false` (VM-Neubau, State/Secrets/Code unberührt) → `k3s_server`-
Rolle um kube-vip-Tasks und `--tls-san` bereinigt → `ansible-playbook site.yml`
→ `tofu apply` (Guest-Agent-Kanal reaktivieren).

### Nachtrag 2 (2026-08-26): kube-vip per kubectl apply – ServiceLB-Konflikt

Zweiter Versuch (nach Boot-Zeit-Manifest-Scheitern oben): kube-vip-RBAC +
DaemonSet (`v1.2.0`, `--controlplane --services --arp`) per `kubectl apply`
gegen den laufenden Cluster angewendet, wie oben als Fix vorgesehen.

**Ergebnis: erneuter Vorfall, andere Ursache.** Nicht dasselbe Problem wie
beim Boot-Zeit-Manifest (kein IPv4-Verlust der Node-eigenen Adresse), sondern:

- k3s installiert standardmäßig **Traefik** als `type: LoadBalancer`-Service.
- k3s' eingebautes **ServiceLB (Klipper)** weist solchen Services **die IPs
  aller berechtigten Nodes** als External-IPs zu (Standardverhalten, siehe
  k3s-Doku „Networking Services").
- kube-vip mit `--services` (`svc_enable: true`) beobachtet genau diese
  LoadBalancer-Services und übernimmt deren External-IP-Liste zur
  ARP-Advertisement. Da es **eine globale Leader-Election** gibt (nicht pro
  Service), bindet der gewählte Leader-Node **alle** diese Adressen lokal
  (`ip addr … deprecated`) – beobachtet: sämtliche Server- UND Agent-IPs
  (`.160`–`.164`) auf dem jeweiligen Leader.
- Folge: ARP-Antworten für fremde Node-IPs, dadurch fehlgeleiteter
  etcd-Peer-Traffic (Port `2380`) zwischen den Servern → Quorum-Verlust →
  API-Server bleibt im Start hängen (`ServiceUnavailable`, `no leader`).

**Diagnose-Weg, der funktioniert hat, als Netzwerk/SSH bereits unzuverlässig
waren:** QEMU-Guest-Agent (`qm guest exec <vmid> -- …` auf `pve2`) – läuft
über virtio-serial, umgeht Netzwerk/ARP vollständig, führt Befehle direkt als
root aus. Damit: Adressen inspiziert/bereinigt (`ip addr del … dev eth0`),
kube-vip-Container gezielt gestoppt (`k3s crictl stop`), DaemonSet gelöscht
(`k3s kubectl delete daemonset kube-vip-ds -n kube-system`).

**Entscheidung:** Nach Bereinigungsversuchen und anhaltender Instabilität
(mehrfache CrashLoopBackOff-Zyklen von kube-vip, jeder Zyklus schrieb die
Adressen erneut) Entschluss zum vollständigen Neuaufbau statt Weiter-Debugging
im laufenden System: `tofu destroy` + kompletter Bring-up von Null.

**Fix vor erneutem kube-vip-Einsatz (noch nicht umgesetzt):** entweder
`--disable servicelb` beim k3s-Server-Start ergänzen (Traefik-LB-Funktion
entfällt dann bis zu einem bewussten Ersatz, z. B. MetalLB oder Ingress ohne
LB-Type), oder `--services`/`svc_enable` aus dem kube-vip-Manifest vorerst
entfernen und erst in Phase 4 zusammen mit dem echten Ingress-Konzept wieder
aktivieren. `cluster/kube-vip/*.yaml` liegen bereits im Repo, mit
Warnkommentar versehen – **nicht ohne diesen Fix erneut `kubectl apply`en.**

**Nebenbefund, separat vom kube-vip-Vorfall:** `debian-13-genericcloud-amd64.qcow2`
unter `.../trixie/latest/` ist ein rollierender Pointer (ändert sich pro
Debian-Point-Release), der in `images.tf` hinterlegte SHA512-Checksum war
dadurch veraltet (`checksum mismatch` beim Neuaufbau). Zusätzlich zeitweiser
Ausfall von `cloud.debian.org` selbst während des Vorfalls. Fix: aktuellen
Hash aus `SHA512SUMS` neu ziehen. Strukturisches Follow-up (noch offen):
Checksum dynamisch per `data "http"`-Source statt hartkodiert beziehen, oder
auf eine datierte Build-URL wechseln – eigener kleiner ADR-Nachtrag wert.

## Aktueller Stand (Ende Session 2026-08-26)

Neuaufbau von Null **erfolgreich abgeschlossen**. Zwei Nacharbeiten
unterwegs nötig (beide committed):

- `infra/live/homelab/images.tf`: SHA512-Checksum aktualisiert (Debian-
  Point-Release-Wechsel, siehe Nachtrag oben).
- `bootstrap/roles/k3s_server/tasks/main.yml`: `ansible.builtin.file`-Task
  ergänzt, der `/etc/rancher/k3s` anlegt, bevor die `tls-san`-Config dorthin
  geschrieben wird – fehlte bisher, weil das Verzeichnis bei den vorher
  bereits laufenden Servern schon existierte und der Fall beim Von-Null-Bau
  nie getestet wurde.
- `502`-Fehler beim State-Backend während des Versuchs: RustFS-Dienst war
  kurzzeitig down, kein Code-/Config-Problem – durch Neustart des Dienstes
  gelöst.

**Verifiziert:**
- Alle 5 Nodes `Ready` (3 Server `control-plane,etcd` + 2 Agents).
- API-Server-Zertifikat enthält `192.168.0.170` (VIP) als SAN, **ohne**
  separaten Rolling-Restart – der `tls-san`-Task lief wie vorgesehen vor dem
  allerersten k3s-Start.

**Bewusst NICHT gemacht:** kube-vip-RBAC/DaemonSet erneut angewendet. Grund
siehe Nachtrag oben (ServiceLB/Klipper-Konflikt) – Fix-Entscheidung
(`--disable servicelb` vs. `--services` vorerst entfernen) steht noch aus.

## Nächster Schritt (Phase 3 – kube-vip nachrüsten, Fortsetzung)

1. **Architektur-Entscheidung zuerst**, vor jedem erneuten `kubectl apply`:
   `--disable servicelb` beim k3s-Server-Start ergänzen, oder `--services`
   aus `cluster/kube-vip/daemonset.yaml` vorerst entfernen (nur
   `--controlplane`, Traefik-LB bleibt vorerst bei Klipper). Trade-offs siehe
   Nachtrag oben.
2. Erst danach: kube-vip RBAC + DaemonSet erneut anwenden, mit dem gewählten
   Fix.
3. Verifikation: VIP erreichbar, IPv4-Stabilität über längeren Zeitraum
   beobachten (Lehre aus **beiden** gescheiterten Versuchen).
4. Danach: ADR-0010 (inkl. Lessons-Learned aus beiden kube-vip-Vorfällen).

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

## Reproduzierbarer Node-Bring-up (Neuaufbau von Null)

Der Recovery-Weg oben lief zunächst nur, weil die Befehle manuell in der
richtigen Reihenfolge eingegeben wurden – das Playbook selbst erzwang nichts.
Seit dem `site.yml`-Tagging (`prep` / `k3s`) ist die Reihenfolge nicht mehr
von der manuellen Befehlsfolge abhängig, sondern strukturell erzwungen:

```bash
tofu destroy
tofu apply -var agent_enabled=false   # VMs ohne Guest-Agent-Kanal (ADR-0009)
ansible-playbook site.yml --tags prep # Guest-Agent-Paket + Hygiene, noch kein k3s
tofu apply                            # Kanal aktivieren, EIN Reboot – vor k3s, nicht danach
ansible-playbook site.yml --tags k3s  # erst jetzt k3s_server + k3s_agent
```

**Warum die Trennung zwingend ist:** Der zweite `tofu apply` rebootet die VMs
(`reboot_after_update`). Liefe k3s zu dem Zeitpunkt schon, würde OpenTofu einen
laufenden etcd-Cluster unkontrolliert (nicht `serial`, keine Ansible-Reihenfolge)
neu starten – unnötiges Risiko, ähnlich riskant wie der kube-vip-Vorfall oben.

*(Wandert nach Phase-3-Abschluss inkl. kube-vip als finale Fassung in die
README unter „Reproduzieren" – siehe TODO dort.)*

## Nächster Schritt (Phase 3 – kube-vip nachrüsten)
- ✅ `tls-san`-Config als Ansible-Task ausgerollt: `roles/k3s_server/templates/config.yaml.j2`
  + Template-Task in `roles/k3s_server/tasks/main.yml` (bewusst VOR dem
  bestehenden Install-Task, damit ein Von-Null-Neubau die VIP von Anfang an
  im Zertifikat hat, kein nachträglicher Restart nötig). Verifiziert per
  `--check --diff`, danach scharf auf allen 3 Servern gelaufen
  (`changed=1` je Server). `/etc/rancher/k3s/config.yaml` mit
  `tls-san: 192.168.0.170` liegt jetzt auf `srv-1`–`srv-3`.
  ✅ Rolling-Restart über neue Play in `site.yml` (Tag `kube-vip-restart`,
  `serial: 1`, `wait_for` auf Port 6443 zwischen den Nodes) auf allen 3
  Servern gelaufen. Verifiziert per `openssl s_client` gegen
  `192.168.0.160:6443`: API-Server-Zertifikat enthält `192.168.0.170` als
  SAN. **tls-san-Teilschritt damit abgeschlossen.**

## Repo-Struktur

    .
    ├── docs/
    │   ├── adr/           # Architektur-Entscheidungen (0001–0009, 0010 offen)
    │   ├── runbooks/      # Betrieb/Reproduktion laufender Systeme
    │   └── STATUS.md      # dieser Kontext-Anker
    ├── infra/             # OpenTofu
    │   ├── modules/
    │   │   └── vm/        # wiederverwendbares VM-Modul (inkl. on_boot)
    │   │                  #   (main/variables/outputs/versions.tf)
    │   └── live/homelab/  # konkrete Umgebung: backend.tf, encryption.tf,
    │                      #   variables.tf, provider.tf, image.tf,
    │                      #   k3s-nodes.tf, secrets.sops.yaml (verschlüsselt)
    ├── bootstrap/         # k3s-Installation via Ansible
    │   ├── ansible.cfg
    │   ├── inventory/hosts.yml       # k3s_primary-Flag bei srv-1
    │   ├── group_vars/all.yml        # k3s_token, k3s_version
    │   ├── roles/
    │   │   ├── prep/                 # Node-Vorbereitung (Phase 3a)
    │   │   ├── k3s_server/           # cluster-init / Join (Server)
    │   │   └── k3s_agent/            # Join (Agent)
    │   └── site.yml                  # Haupt-Playbook, 4 Plays, Tags prep/k3s
    ├── cluster/           # k8s-/GitOps-Manifeste (Phase 5, noch leer)
    ├── mise.toml          # Tool-Versionen gepinnt (inkl. kubectl 1.36.3)
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
  Werkzeug-Grenze Tofu/Ansible, kube-vip Boot-Zeit-Manifest vs. nachträglicher
  Apply) – schreiben, sobald kube-vip nachgerüstet und verifiziert ist.

## Kontext / Details
- Entscheidungen: `docs/adr/0001`–`0009` (0002 ersetzt durch 0006;
  0004 + 0009 mit Nachträgen vom 2026-08-25; 0009 = VM-Provisioning:
  Cloud-Image-Import + natives cloud-init); 0010 offen (Config-Management,
  siehe „Offen" oben)
- Betrieb State-Backend: `docs/runbooks/state-backend-rustfs.md`
- Proxmox-Zugang: `docs/runbooks/proxmox-access.md`
