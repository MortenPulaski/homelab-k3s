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

## Nachtrag (2026-08-24): Off-Host-State-Kandidaten für Phase 6

Recherche-Notiz, **keine** Entscheidung. Kontext: Ab Phase 6 (CI/CD) brauchen
flüchtige Runner ein erreichbares Remote-State-Backend, das **nicht** von `pve2`
abhängt – der RustFS-LXC liegt auf `pve2`, was für CI ein Erreichbarkeits- und
Schreibkonflikt-Risiko ist (siehe Konsequenz „Kein Remote-Lock"). Für diesen Fall
wurden S3-kompatible Off-Host-Backends gesichtet.

**Kosten-Fazit vorab:** Der Tofu-State ist winzig (wenige MB, seltene Änderung).
Bei allen Kandidaten liegen die Kosten dafür bei **Cent-Beträgen oder null**
(Rechenbeispiele: AWS S3 Frankfurt ~$0,004–0,12/Monat; Scaleway ~€0,0004–0,08/Monat).
Der Preis ist damit **kein** Entscheidungskriterium – es zählen die qualitativen
Achsen. Preisstand: 2026-08.

Kandidaten nach Achse:

- **Gratis + off-host:** Cloudflare R2 (10 GB Storage/Monat dauerhaft frei,
  Zero-Egress, natives S3) oder Oracle Cloud Object Storage (Always Free, Konto
  bereits vorhanden). Beide US-Recht (CLOUD Act).
- **Maximaler Lerneffekt:** AWS S3 (industrieübliches `backend "s3"`, dazu
  IAM/KMS/CloudTrail als eigenständiger Portfolio-Wert). Achtung: neues
  Free-Tier-Modell (seit 15.07.2025) = $100–200 Guthaben / 6 Monate, danach
  Account-Schließung. Fürs *dauerhafte* Backend zwingend Paid-Plan; als
  *befristete Lernübung* im Guthaben-Fenster faktisch $0. Egress im Maßstab teuer
  (100 GB/Monat frei, dann $0,09/GB) – für einen State irrelevant.
- **EU-Datenhoheit:** IONOS Object Storage (deutsch, ISO-27001/DSGVO, kein CLOUD
  Act; Versioning via Object Lock/WORM; **kein** Free-Tier, Angebot nur für
  Gewerbetreibende) oder Scaleway (französisch, Multi-Region PAR/AMS/WAW;
  Versioning; 75 GB Egress/Monat frei + 3-Monats-Storage-Trial).

**Verworfen:** Hetzner Object Storage – trotz gutem Preis und EU-Standort **kein
Objekt-Versioning** → als State-Backend (Recovery-Netz) ungeeignet.

Offene technische Frage vor CI-Einsatz: Ob der jeweilige Anbieter
S3-Conditional-Writes (`If-None-Match`) für `use_lockfile` robust umsetzt, ist pro
Kandidat in der S3-API-Doku zu verifizieren, bevor CI-Locking darauf aufgebaut wird
(self-hosted RustFS tut es aktuell nicht, daher `use_lockfile = false`).

Entscheidung bleibt bewusst **offen bis Phase 6**.
