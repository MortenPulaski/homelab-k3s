# ADR-0005: Secrets-Management mit SOPS + age

- **Status:** akzeptiert
- **Datum:** 2026-08-22

## Kontext

Geheimnisse (MinIO-Zugangsdaten fürs State-Backend, API-Tokens, später
Kubernetes-Secrets) müssen mit dem Code leben, dürfen aber im öffentlichen Repo
nicht lesbar sein. Zwei naheliegende Wege scheitern:

- **Nur per `.gitignore` draußen halten:** nicht reproduzierbar, nicht in Git –
  und für GitOps untauglich, da dort der komplette Zustand (inkl. Secrets) in
  Git liegen muss.
- **Klartext committen:** im öffentlichen Repo sofortiger Verlust.

Gebraucht wird: Secrets **versioniert in Git**, aber **unlesbar** für Dritte.

## Entscheidung

**SOPS** verschlüsselt gezielt die *Werte* (nicht die Struktur) von
Konfigurationsdateien; als Krypto-Backend dient **age** (ein einzelnes
Schlüsselpaar, moderner GPG-Nachfolger).

- Regeldatei `.sops.yaml` im Repo, mit dem **öffentlichen** age-Schlüssel als
  Empfänger (die Datei enthält kein Geheimnis und wird committet).
- Privater Schlüssel unter `~/.config/sops/age/keys.txt` (SOPS-Standardpfad),
  **nie im Repo**.
- `sops` und `age` sind über mise gepinnt (siehe `mise.toml`).

## Konsequenzen

- **Ein** konsistentes Secrets-Verfahren über den ganzen Stack: OpenTofu liest
  SOPS-verschlüsselte Werte (SOPS-Provider), später entschlüsseln Flux (nativ)
  bzw. ArgoCD (Plugin) SOPS-Secrets im Cluster mit demselben Prinzip.
- Werte sind Chiffretext, Struktur/Diff bleiben lesbar – Git bleibt nutzbar.
- **Envelope Encryption** erlaubt mehrere Empfänger (Laptop, CI, Kollege), ohne
  das Geheimnis selbst zu teilen.
- **Der private age-Schlüssel ist das Kronjuwel:** Leak = alle Secrets offen;
  Verlust = Secrets unwiderruflich verloren. Er muss außerhalb der Maschine
  gesichert werden (Passwortmanager/verschlüsseltes Backup).

## Abgrenzung

Komplementär zur **OpenTofu-State-Verschlüsselung**: Diese schützt, was
*automatisch* in den State fließt; SOPS schützt die Secrets, die *bewusst* ins
Repo gelegt werden (tfvars, Backend-Credentials).

## Alternativen

- **GPG als Backend:** funktioniert, bringt aber Keyring-/Trust-/Ablauf-Ballast;
  age ist bewusst einfacher.
- **Cloud-KMS (AWS/GCP/Azure):** stärker im Team-/Cloud-Kontext, bindet aber an
  einen Anbieter. Später relevant, sobald eine echte Cloud dazukommt – dasselbe
  SOPS-Prinzip, nur der Schlüssel liegt beim Cloud-KMS.
