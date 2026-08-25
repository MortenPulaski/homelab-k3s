# ADR-0009: VM-Provisioning – Cloud-Image-Import + natives cloud-init

- **Status:** akzeptiert
- **Datum:** 2026-08-25

## Kontext

Phase 2 provisioniert die k3s-VMs erstmals als echtes IaC. Vor der ersten
Ressource stellen sich zwei Grundsatzfragen, die beide das bewusst schmal
gehaltene Zugriffsmodell aus ADR-0006 / `proxmox-access.md` berühren (nur
API-Token, **kein** SSH auf den PVE-Host):

1. Wie kommt das Basis-OS-Image auf den Host und in die VM?
2. Wie wird die VM beim ersten Boot konfiguriert (IP, User, SSH-Key)?

Der `bpg/proxmox`-Provider bietet je Frage zwei Wege:

- **Image:** `download_file` + `import_from` (Disk-Import aus dem Cloud-Image)
  vs. eine vorab gebaute Template-VM + `clone`.
- **cloud-init:** nativ (`initialization`-Block, nur API) vs. custom
  cloud-config als Snippet (`proxmox_virtual_environment_file`).

Entscheidende technische Randbedingung: Der Snippet-Upload läuft beim
bpg-Provider **über SSH** auf den PVE-Host (die PVE-API kann keine
Snippet-Dateien hochladen). Natives cloud-init kann dafür **keine Pakete
installieren** – insbesondere nicht den `qemu-guest-agent`.

## Entscheidung

**Natives cloud-init (nur API) + Cloud-Image-Import via
`download_file`/`import_from`.**

- cloud-init über den `initialization`-Block: statische IP (aus dem IP-Plan,
  ADR-0008), `user_account` mit SSH-Public-Key. Läuft vollständig über das
  bestehende `PROXMOX_VE_API_TOKEN` – **kein SSH-Zugang zum Host nötig**.
- Weil natives cloud-init keine Pakete installiert: `agent { enabled = false }`
  + `stop_on_destroy = true` in Phase 2. `qemu-guest-agent` und die eigentliche
  Node-Vorbereitung wandern nach Phase 3 (Ansible, `bootstrap/`).
- Klare Werkzeug-Grenze: **Tofu provisioniert** (VM, Disk, Netz, Identität),
  **Ansible konfiguriert** (Pakete, Dienste, k3s-Prep).
- Image: `download_file` (Content-Type `import`, Ziel `local`) zieht das
  Debian-genericcloud-qcow2; die VM übernimmt es per `import_from` als
  Boot-Disk auf ZFS `lab`. Kein manueller Template-Bau.

## Konsequenzen

- Das Least-Privilege-Zugriffsmodell bleibt unangetastet (kein SSH-User, keine
  zusätzlichen Credentials in SOPS). Einzige Erweiterung ist die Rolle selbst
  (drei beim VM-Create real angeforderte Rechte – `Datastore.AllocateTemplate`,
  `VM.Config.HWType`, `SDN.Use`; siehe `proxmox-access.md`).
- Saubere Trennung Tofu/Ansible; die Config-Management-Ebene (Phase 3) bekommt
  einen klar abgegrenzten Aufgabenbereich statt Boot-Zeit-Logik in der IaC.
- Kein IP-Readback über den Guest-Agent in Phase 2 – unkritisch, da IPs statisch
  vergeben werden. Verifikation der VM erfolgt direkt per SSH.
- Alles bleibt in **einem** Code-Fluss (Download → VM), gut nachvollziehbar und
  ohne Zwischenschritt außerhalb der IaC.
- `agent { enabled = false }` muss in Phase 3 auf `true` gedreht werden, sobald
  Ansible den Agent installiert hat (dann wird `VM.GuestAgent.Audit` wirksam).

## Alternativen

- **Custom cloud-init (Snippet, SSH):** mächtiger – installiert Agent + Pakete
  beim ersten Boot, setzt den Hostname frei. Verworfen für Phase 2, weil er
  SSH-Zugang zum PVE-Host verlangt: zusätzliche Credentials und erweiterte
  Angriffsfläche, im Widerspruch zum bewusst API-only-Modell. Später denkbar,
  falls Boot-Zeit-Konfiguration ohne Ansible gewünscht ist – dann eigener ADR.
- **Template-VM + `clone`:** schneller bei vielen VMs (Linked Clones), verlangt
  aber eine vorab (manuell oder separat) gebaute Template – ein Schritt außerhalb
  des durchgängigen Code-Flusses. Für fünf Nodes ist der Zeitvorteil gering;
  verworfen zugunsten der Nachvollziehbarkeit. Neu zu bewerten, falls die
  Node-Zahl deutlich wächst.
- **qemu-guest-agent doch in Phase 2 (also custom cloud-init):** verworfen –
  Node-Konfiguration gehört bewusst zu Ansible, nicht in die Provisionierung.

## Abgrenzung

Diese Entscheidung betrifft, *wie* eine VM entsteht und erstkonfiguriert wird.
*Welche* VMs es gibt (Topologie, IP-Plan) regelt ADR-0008; die Modul-Struktur
(`modules/vm` + `for_each`) ist Umsetzungsdetail und kein eigener ADR.

## Nachtrag (2026-08-25): Agent-Aktivierung ist zweistufig

Belegt (dpkg.log auf einem Node): Das Debian-13-genericcloud-Image bringt
`qemu-guest-agent` NICHT mit (Vorzustand `<none>`, Installation erst durch die
Ansible-prep-Rolle). `agent.enabled = true` lässt sich daher nicht als reine
Erstellungs-Eigenschaft setzen: Das Paket kommt erst nach dem VM-Create auf den
Node, und `agent = true` bei nicht-laufendem Agent führt laut bpg-Doku zu
Timeout/Lock bei Proxmox-Shutdown/Reboot.

Gesteuert wird das über die Root-Variable `agent_enabled` (live-Default `true`,
Modul-Default `false`). Der Wert fließt: Root-Variable → Modulaufruf →
Modul-Eingabevariable → `agent { enabled = ... }`. Nur die Root-Variable ist per
`-var` von außen übersteuerbar; der Modul-Default `false` ist die Absicherung,
falls die Root-Variable einmal fehlt.

Steady state: nichts angeben → Default `true`, Agent an.

Von-Null-Neubau, zweistufig:

1. `tofu apply -var agent_enabled=false` → VMs entstehen ohne Agent-Kanal.
2. `ansible-playbook site.yml` → installiert den Agent auf den Nodes.
3. `tofu apply` (fällt auf den Default `true` zurück) → Kanal wird aktiviert;
   der Provider rebootet die VMs dabei selbst (`reboot_after_update` per Default
   true, nicht-hotplugfähige Änderung), wodurch der virtio-serial-Kanal
   erscheint und der Agent von selbst hochkommt. Nur falls der
   Pre-Reboot-guest-ping hängt (bpg-Issue #2029), den betroffenen Node einmal
   manuell stop/start.

Der laufende Betrieb fasst `agent_enabled` nicht an — es ist ein
Bring-up-Schalter, kein Betriebs-Dial.
