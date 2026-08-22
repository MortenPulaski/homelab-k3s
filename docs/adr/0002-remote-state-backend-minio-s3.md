# ADR-0002: Remote-State auf MinIO (S3-kompatibel)

- **Status:** akzeptiert
- **Datum:** 2026-08-22

## Kontext

Der OpenTofu-State ist die Zuordnungstabelle zwischen Code und realen
Ressourcen und enthält Klartext-Werte (Tokens, Keys). Er darf nicht ins
öffentliche Repo, muss haltbar/wiederherstellbar sein und ist Voraussetzung
für spätere CI/CD (flüchtige Runner haben keinen lokalen State).

## Entscheidung

Remote-State in einem selbstgehosteten, S3-kompatiblen MinIO-Bucket über den
`backend "s3"` mit Endpoint-Override. Locking via `use_lockfile = true`
(nativ ab OpenTofu 1.10, kein DynamoDB). Bucket-Versioning aktiviert.
Zusätzlich OpenTofu State Encryption (client-seitig) aktiv.

Einstieg pragmatisch: zunächst lokaler, verschlüsselter State; Migration nach
MinIO als eigener, dokumentierter Meilenstein (`tofu init -migrate-state`).

## Konsequenzen

- Produktionsnahes Muster (identische `backend "s3"`-Konfig wie auf AWS).
- MinIO ist ein zusätzlicher Dienst und muss vor `tofu` existieren
  (Bootstrapping out-of-band, nicht vom eigenen State verwaltet).
- Versioning schützt vor versehentlichem State-Verlust.

## Alternativen

- **Lokal + Verschlüsselung:** einfachste Variante, aber kein Remote-Workflow
  und an eine Maschine gebunden. Als Startpunkt genutzt, nicht als Ziel.
- **Managed TACO (Spacelift/Scalr/env0):** mehr Komfort, aber SaaS-Abhängigkeit;
  fürs Lernen des Backend-Mechanismus bewusst nicht gewählt.
