# ADR-0006: State-Backend auf RustFS (ersetzt MinIO aus ADR-0002)

- **Status:** akzeptiert
- **Datum:** 2026-08-22
- **Ersetzt:** ADR-0002 (MinIO)

## Kontext

ADR-0002 legte MinIO als S3-kompatibles State-Backend fest. Inzwischen ist die
**MinIO Community Edition End-of-Life**: Admin-Konsole entfernt (2025), keine
vorgefertigten Binaries/Images mehr, Maintenance-Mode, GitHub-Repo im April 2026
archiviert. Ein archiviertes, quelltext-only Tool ist kein tragfähiges Fundament
für die IaC.

Bei der Suche nach Ersatz zeigte sich zusätzlich: Das native S3-Lockfile
(`use_lockfile`) beruht auf S3-Conditional-Writes (`If-None-Match`), und die
selbstgehosteten S3-Implementierungen setzen das noch nicht robust um –
besonders zusammen mit Versioning:

- **Garage:** kein Objekt-Versioning; `if-none-match` laut eigener Doku nicht
  sicher für gegenseitigen Ausschluss. → als State-Backend ungeeignet.
- **SeaweedFS:** Versioning ja, aber schwergewichtiger (Master/Volume/Filer);
  Conditional-Write bei Versioning+Locking fehlerhaft (offener Bug).
- **RustFS:** volle S3-Versionierung; Tofu-Locking auf versioniertem Bucket
  aktuell fehlerhaft (offener Bug) – für uns irrelevant, siehe Entscheidung.

## Entscheidung

**RustFS** als S3-kompatibles State-Backend, betrieben in einem eigenen LXC
(Bootstrap-Infrastruktur, außerhalb der IaC, die es hostet).

- **Versioning: an** – das eigentliche Sicherheitsnetz für State-Recovery.
- **`use_lockfile`: aus** – Locking schützt vor *gleichzeitigen* Schreibern, die
  es im Solo-Betrieb nicht gibt; zudem ist die self-hosted-Unterstützung unreif.
  Ohne `use_lockfile` deaktiviert Tofu das Locking sauber (kein Fehler).
- **OpenTofu State Encryption: an** (client-seitig), wie in ADR-0002.

## Konsequenzen

- Behält das industrieübliche `backend "s3"`-Muster (identisch zu AWS) – der
  Lerneffekt aus ADR-0002 bleibt erhalten.
- Versioning ermöglicht das Zurückrollen eines beschädigten/gelöschten State.
- **Kein Remote-Lock.** Akzeptabel solo; **neu zu bewerten, sobald CI (Phase 6)**
  eine zweite Schreibquelle einführt (dann CI-Läufe serialisieren oder ein
  Locking-Verfahren nachrüsten).
- RustFS ist jünger/weniger erprobt als MinIO – bewusster Homelab-Kompromiss.

## Alternativen

- **Garage:** verworfen (kein Versioning, kein sicheres Locking).
- **SeaweedFS:** funktional möglich, aber mehr bewegliche Teile als nötig.
- **PostgreSQL-Backend:** echtes, robustes Locking (Advisory Locks), sehr einfach
  – aber verliert das S3-/AWS-Lernmuster. Für das Employability-Ziel verworfen.
