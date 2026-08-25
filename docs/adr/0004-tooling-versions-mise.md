# ADR-0004: Werkzeug-Versionen über mise pinnen

- **Status:** akzeptiert
- **Datum:** 2026-08-22

## Kontext

Tools über apt (systemweit) zu installieren bindet die Version an die einzelne
Maschine und an die Distributions-Logik – nicht ans Projekt. Für reproduzierbare
Ergebnisse (lokal wie in CI) muss die Werkzeugversion Teil des Repos sein.

## Entscheidung

Werkzeug-Versionen werden über **mise** in einer committeten `mise.toml`
gepinnt – zunächst OpenTofu (v1.12.6), später kubectl/helm. mise aktiviert pro
Projektordner automatisch die passende Version (`mise activate`).

mise wird auf Ubuntu 26.04 über die offizielle **PPA** (`ppa:jdxcode/mise`)
installiert – der vom Maintainer für diese OS-Version empfohlene Weg.

## Konsequenzen

- Reproduzierbar: gleiches Tool, gleiche Version für alle und für die Pipeline.
- Ein zusätzliches Werkzeug (mise) als Voraussetzung auf der Arbeitsmaschine.
- Systemweite apt-Installationen desselben Tools werden entfernt, um
  PATH-Konflikte zu vermeiden.
- Nach dem Klonen: `mise trust` + `mise install` holt exakt die gepinnten Tools.

## Alternativen

- **apt / systemweit:** einfachste Variante, aber nicht projekt-reproduzierbar;
  liefert zudem oft nicht die gewünschte Version.
- **asdf:** gleiches Prinzip, aber langsamer und weniger aktiv gepflegt als mise.

## Nachtrag (2026-08-25): Pin-Politik präzisiert

Nicht jedes Werkzeug wird exakt gepinnt. Leitlinie:

- **Ergebnis-bestimmende Werkzeuge exakt pinnen** – ihre Version beeinflusst das
  Resultat: OpenTofu (State-Format, Provider-/HCL-Verhalten), sops/age
  (Krypto-Format der Secrets), Ansible (Modul-Verhalten, core-Version →
  Playbook-Ergebnis; besonders für reproduzierbare CI-Läufe ab Phase 6).
- **Reine Komfort-/Bedien-Werkzeuge dürfen auf `latest` laufen** – sie ändern
  den Zustand der Infrastruktur nicht: `github-cli` (Repos/PRs/Actions-Secrets,
  laut `setup.md` optional).

Damit ist `github-cli = "latest"` eine bewusste Ausnahme, keine Nachlässigkeit.
