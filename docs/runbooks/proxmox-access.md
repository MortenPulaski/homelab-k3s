# Runbook: Proxmox-Zugang für OpenTofu

Wie der API-Zugriff für OpenTofu auf Proxmox VE eingerichtet ist.

## Überblick

- **Proxmox-Version:** 9.2.11 (`pve-manager/9.2.11/f6997e698c7933ea`)
- **Host:** `pve2`, TLS-Zertifikat gültig (kein `insecure = true` im Provider nötig)
- **Auth-Methode:** dediziertes User + Custom Role + API-Token (least-privilege,
  analog zum RustFS-Access-Key, siehe ADR-0006)
- **User:** `tofu@pve` (Realm `pve`, kein PAM-User)
- **Rolle:** `TofuRole`
- **Token-ID:** `provider` (ohne Privilege Separation, `--privsep 0` – Token
  erbt die Rechte des Users statt eigener, separater Rechte)

## Netzwerk

- **Proxy-Host (NPM):** `pve2.marpal-it.de` → `http://<proxmox-ip>:8006`
  - Let's-Encrypt-Zertifikat via DNS-01-Challenge.
  - Split-Horizon-DNS (AdGuard Home): `pve2.marpal-it.de` löst nur im
    lokalen Netzwerk auf.

## Hinweis: Rechte-Eigenheiten unter Proxmox VE 9

Seit Proxmox VE 9.0 ist das Privileg `VM.Monitor` entfernt (ersetzt durch
`Sys.Audit` für Informationsabfragen sowie feingranulare
`VM.GuestAgent.*`-Rechte). Ältere Terraform/OpenTofu-Anleitungen, die
`VM.Monitor` noch listen, schlagen auf PVE 9.x mit
`invalid privilege 'VM.Monitor'` fehl.

Beim ersten realen VM-Create (Phase 2) forderte der `bpg/proxmox`-Provider
iterativ drei weitere Rechte an, die im reinen Auth-Test aus Phase 1 (keine
`resource`, nur `plan`) nie auftraten:

- `Datastore.AllocateTemplate` – Download des Cloud-Images über die
  download-url-API (zusätzlich zu `Sys.Audit`/`Sys.Modify`). Nicht
  PVE-9-spezifisch, aber erst mit dem Image-Download nötig.
- `VM.Config.HWType` – Setzen von Maschinentyp/BIOS/SCSI-Controller, das der
  Provider beim Create implizit vornimmt.
- `SDN.Use` – unter PVE 8/9 liegt auch eine einfache Linux-Bridge in der
  SDN-Zone `localnetwork`; eine NIC an `vmbr0` zu hängen verlangt daher
  `SDN.Use` auf `/sdn/zones/localnetwork/vmbr0`. Propagiert von `/`, also
  durch die bestehende ACL abgedeckt.

Least-Privilege-Logik wie beim übrigen Rollenzuschnitt: real beim VM-Create
angefordert, nicht vorsorglich gesetzt.

## Rolle anlegen

```bash
pveum role add TofuRole -privs "VM.Allocate VM.Audit VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.Config.Cloudinit VM.Config.HWType VM.PowerMgmt VM.Migrate VM.GuestAgent.Audit Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Sys.Audit Sys.Modify SDN.Use"
```

> Werden Rechte nachträglich ergänzt (wie in Phase 2 geschehen), `pveum role
> modify TofuRole -privs "…"` mit der **vollständigen** Liste verwenden –
> `modify` ersetzt die Priv-Liste, ergänzt sie nicht.

`VM.GuestAgent.Audit` (lesend) ist enthalten, da der `bpg/proxmox`-Provider den
QEMU-Guest-Agent nutzt, um nach dem Boot Statusdaten (z. B. die vergebene
IP-Adresse) auszulesen. In Phase 2 läuft die VM bewusst **ohne** Agent
(`agent { enabled = false }`, statische IP via cloud-init); relevant wird das
Recht ab Phase 3, sobald der Guest-Agent via Ansible installiert und
`agent { enabled = true }` gesetzt ist. Schreibende Guest-Agent-Rechte
(`VM.GuestAgent.FileWrite`, `.Unrestricted`) sind bewusst **nicht** enthalten
(Least-Privilege).

## User anlegen und Rolle zuweisen

```bash
pveum user add tofu@pve
pveum aclmod / -user tofu@pve -role TofuRole
```

ACL-Pfad `/` = Datacenter-Root; die Rolle propagiert (`*`) in alle
Unterpfade (`/vms`, `/storage`, `/nodes`, `/sdn`, …).

## API-Token erzeugen

```bash
pveum user token add tofu@pve provider --privsep 0
```

Gibt **einmalig** das Secret aus, Format: `tofu@pve!provider=<secret>`.

## Ablage

SOPS-verschlüsselt in `infra/live/homelab/secrets.sops.yaml` als
`PROXMOX_VE_API_TOKEN` (Umgebungsvariable, wie vom `bpg/proxmox`-Provider
erwartet). mise lädt und entschlüsselt automatisch beim Betreten des Projekts
(gleiches Muster wie die RustFS-S3-Credentials).

## Provider-Konfiguration (Tofu)

Konfiguriert in `infra/live/homelab/provider.tf`:

- `endpoint = "https://pve2.marpal-it.de/"`
- Provider `bpg/proxmox`, Version `0.111.1` (exakt gepinnt, kein Range –
  konsistent zum mise-Pinning-Prinzip, siehe ADR-0004)
- Kein `insecure = true` nötig (gültiges TLS-Zertifikat via NPM)
- Auth über `PROXMOX_VE_API_TOKEN` aus `secrets.sops.yaml` (siehe Abschnitt
  „Ablage" oben) – kein Token-Wert im Provider-Block selbst

Initial verifiziert (Phase-1-Setup, vor der ersten Ressource):

```bash
tofu init
tofu plan
```

Ergebnis damals: `No changes. Your infrastructure matches the configuration.`
– reiner Auth-/Verbindungstest, da noch keine `resource`-Blöcke existierten.
Ab Phase 2 verwaltet `plan`/`apply` reale Ressourcen (Cloud-Image-Download,
VMs); die Verbindungs- und Auth-Mechanik ist dabei dieselbe.

## Verifikation (Proxmox-Rechte)

```bash
pveum user permissions tofu@pve
```

Zeigt die tatsächlich zugewiesenen Rechte je ACL-Pfad zur Kontrolle. Erwartet:
die oben unter „Rolle anlegen" gelisteten Privilegien, von `/` auf alle
Unterpfade propagiert.
