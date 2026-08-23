# Runbook: State-Backend (RustFS)

Wie das OpenTofu-State-Backend aufgesetzt und betrieben wird.

> **Bootstrap-Infrastruktur, außerhalb der IaC.** Dieses Backend hostet den
> Tofu-State und darf deshalb *nicht* von dem Tofu-Projekt verwaltet werden,
> dessen State es speichert. Es wird von Hand gemäß diesem Runbook aufgesetzt.
> Siehe ADR-0006 für die Begründung (RustFS statt MinIO; Versioning an,
> `use_lockfile` aus).

## Überblick

- **Dienst:** RustFS (S3-kompatibel), Single-Node.
- **Host:** Debian-LXC `8001` auf Proxmox (Storage `lab`), unprivilegiert,
  Start-on-Boot an.
- **Ports (intern):** 9000 = S3-API, 9001 = Konsole.
- **Datenverzeichnis:** `/data/rustfs0`
- **Konfiguration:** `/etc/default/rustfs`
- **systemd-Dienst:** `rustfs`

## Netzwerk & TLS

- **Feste IP:** `192.168.0.68` (statisch / DHCP-Reservierung – Pflicht, weil NPM
  als Upstream darauf zeigt).
- **TLS-Terminierung:** über NPM (Nginx Proxy Manager), nicht in RustFS selbst.
- **Proxy-Host (S3-API):** `s3.marpal-it.de` → `http://192.168.0.68:9000`
  - Let's-Encrypt-Zertifikat, „Force SSL" an.
  - **Access-List:** nur LAN/Netbird – das Backend hält Infra-Secrets und ist
    **nicht** öffentlich erreichbar (der Name darf öffentlich auflösen, der
    Zugriff nicht).
  - Advanced-Direktiven (sonst scheitern signierte S3-Anfragen):
    ```nginx
    ignore_invalid_headers off;
    client_max_body_size 0;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_set_header Host $http_host;
    ```
- **Konsole (optional):** eigener Proxy-Host `rustfs.marpal-it.de` →
  `http://<LXC-IP>:9001`, ebenfalls mit Access-List.
- **Tofu-Endpoint:** `https://s3.marpal-it.de` (echtes Zertifikat → kein
  `custom_ca_bundle` in Tofu nötig).

> Hinweis: Die S3-API muss an der **Wurzel** eines eigenen Hosts liegen, nicht
> unter einem Unterpfad – Pfad-basiertes Proxying bricht die SigV4-Signatur.

## Zugangsdaten

- **Root-Credentials** (`RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`) stehen in
  `/etc/default/rustfs` auf dem LXC – **nie** im Repo. Access-Key
  großbuchstaben-alphanumerisch (kein rohes Base64 wegen `/`-Kollision mit
  SigV4).
- **Dedizierter Tofu-Access-Key:** least-privilege, nur auf Bucket `tofu-state`
  (`GetObject`/`PutObject`/`DeleteObject` auf `…/*`, `ListBucket` auf den Bucket).
  Nicht die Root-Credentials. Widerruf-/Rotation über die RustFS-Konsole.
- **Ablage:** SOPS-verschlüsselt in `infra/live/homelab/secrets.sops.yaml` als
  `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. mise lädt und entschlüsselt sie
  beim Betreten des Projekts automatisch (age-Schlüssel via `SOPS_AGE_KEY_FILE`).

## Bucket & Versioning

- Bucket `tofu-state`, **Versioning aktiviert**, Objektsperre **aus** (würde das
  Überschreiben des State und der Lock-Dateien blockieren).

## Backend-Konfiguration (Tofu)

- _TODO (4.5):_ `backend "s3"`-Block in `infra/live/homelab/` mit Endpoint
  `https://s3.<domain>`, Path-Style, `use_lockfile = false`, State-Encryption an;
  Credentials via Umgebungsvariablen aus der SOPS-Datei.

## Betrieb

```bash
systemctl status rustfs --no-pager     # Zustand
systemctl restart rustfs               # Neustart (z. B. nach Config-Änderung)
journalctl -u rustfs -e                # Logs
```

## State wiederherstellen (Versioning)

Wird der State beschädigt, in der RustFS-Konsole am Objekt
`homelab/terraform.tfstate` die Versionsliste öffnen und eine frühere Version
wiederherstellen. Vorher immer die aktuelle Version sichern.
