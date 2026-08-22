# ADR-0001: Architektur-Entscheidungen dokumentieren

- **Status:** akzeptiert
- **Datum:** 2026-08-22

## Kontext

In diesem Projekt treffen wir bewusst technische Entscheidungen (z. B. k3s vs.
kubeadm, VM vs. LXC, State-Backend). Ohne Dokumentation geht das *Warum*
verloren – für mich später und für jeden, der das Repo liest.

## Entscheidung

Jede nennenswerte Entscheidung wird als kurzes ADR (Architecture Decision
Record) unter `docs/adr/NNNN-titel.md` festgehalten, nummeriert und mit
Status, Kontext, Entscheidung und Konsequenzen.

## Konsequenzen

- Das *Warum* bleibt nachvollziehbar; Entscheidungen sind auditierbar.
- Minimaler Overhead pro Entscheidung – bewusst knapp gehalten.
- Im Bewerbungskontext zeigt der ADR-Verlauf strukturiertes Vorgehen.
