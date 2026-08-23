# ADR-0007: State-Verschlüsselung mit PBKDF2

- **Status:** akzeptiert
- **Datum:** 2026-08-23

## Kontext

Der State liegt zwar über TLS übertragen und im Bucket, ist als Datei aber
im Klartext lesbar und enthält ab Phase 2 sensible Werte. Er soll zusätzlich
*at rest* verschlüsselt werden (OpenTofu-eigene State-Encryption, ab 1.7).

OpenTofu bietet dafür die Key-Provider `pbkdf2` (passphrasenbasiert),
`aws_kms`, `gcp_kms`, `azure_keyvault`, `openbao` und einen experimentellen
`external`-Provider. Einen `age`-Provider gibt es **nicht** – age bleibt
ausschließlich für SOPS zuständig.

## Entscheidung

**PBKDF2** als Key-Provider, Methode `aes_gcm`, `enforced = true`.

- Die Passphrase kommt als `TF_VAR_state_encryption_passphrase` aus der
  SOPS-verschlüsselten Datei (von mise geladen) – gleiches Muster wie die
  S3-Credentials.
- Migration des bestehenden Klartext-State einmalig über einen temporären
  `unencrypted`-Fallback; danach Fallback entfernt und `enforced` gesetzt.

## Konsequenzen

- Kein externer Dienst nötig – passt zum self-hosted, Solo-Homelab-Kontext.
- State ist doppelt geschützt: TLS bei der Übertragung, AES-GCM at rest.
- `enforced = true` verhindert versehentliches Schreiben von Klartext-State.
- **Passphrase-Verlust = State unwiederbringlich.** Ablage SOPS-verschlüsselt
  im Repo *und* im Passwortmanager; die CI (Phase 6) braucht sie als Secret.

## Alternativen

- **Cloud-KMS (AWS/GCP/Azure):** bessere Rotation/Audit, aber Anbieterbindung
  und für ein self-hosted Homelab überdimensioniert. Später denkbar, sobald
  eine echte Cloud dazukommt – gleiches Prinzip, Schlüssel liegt dann im KMS.
- **age als Key-Provider:** existiert in OpenTofu nicht. age bleibt für SOPS.
- **Keine State-Verschlüsselung:** verworfen – der State enthält Klartext-Secrets.
