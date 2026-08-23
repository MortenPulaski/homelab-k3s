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

## Hinweis: `VM.Monitor` in PVE 9

Seit Proxmox VE 9.0 ist das Privileg `VM.Monitor` entfernt (ersetzt durch
`Sys.Audit` für Informationsabfragen sowie feingranulare
`VM.GuestAgent.*`-Rechte). Ältere Terraform/OpenTofu-Anleitungen, die
`VM.Monitor` noch listen, schlagen auf PVE 9.x mit
`invalid privilege 'VM.Monitor'` fehl.

## Rolle anlegen

```bash
pveum role add TofuRole -privs "VM.Allocate VM.Audit VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.Config.Cloudinit VM.PowerMgmt VM.Migrate VM.GuestAgent.Audit Datastore.Allocate Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Modify"
```

`VM.GuestAgent.Audit` (lesend) ist enthalten, da der `bpg/proxmox`-Provider den
QEMU-Guest-Agent nutzt, um nach dem Boot die vergebene IP-Adresse einer VM
auszulesen (relevant ab Phase 2). Schreibende Guest-Agent-Rechte
(`VM.GuestAgent.FileWrite`, `.Unrestricted`) sind bewusst **nicht** enthalten
(Least-Privilege).

## User anlegen und Rolle zuweisen

```bash
pveum user add tofu@pve
pveum aclmod / -user tofu@pve -role TofuRole
```

ACL-Pfad `/` = Datacenter-Root; die Rolle propagiert (`*`) in alle
Unterpfade (`/vms`, `/storage`, `/nodes`, …).

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

## Verifikation

```bash
pveum user permissions tofu@pve
```

Zeigt die tatsächlich zugewiesenen Rechte je ACL-Pfad zur Kontrolle.
