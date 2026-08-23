# ADR-0003: Repository-Layout (Monorepo, gegliedert nach Ebene)

- **Status:** akzeptiert
- **Datum:** 2026-08-22

## Kontext

Das Projekt umfasst mehrere Ebenen mit unterschiedlichem Änderungsrhythmus:
Infrastruktur (Proxmox-VMs via OpenTofu, ändert sich selten), k3s-Bootstrapping
(quasi einmalig) und Cluster-Workloads (GitOps, ändern sich laufend). Es braucht
eine Struktur, die das trennt und für Betrachter (auch Recruiter) den ganzen
Bogen an einem Ort lesbar macht.

## Entscheidung

**Monorepo**, gegliedert **nach Ebene/Lebenszyklus** statt nach Anwendung:

```
iac-homelab-k3s/
├── docs/            # README-nahe Doku, ADRs (docs/adr/)
├── infra/           # OpenTofu: Proxmox-VMs
│   ├── modules/     # wiederverwendbare Bausteine
│   └── live/        # konkrete Umgebung(en), verdrahtet die Module
├── bootstrap/       # k3s-Installation (Ansible / cloud-init)
└── cluster/         # Kubernetes-/GitOps-Manifeste (Innenstruktur: Phase 5)
```

## Konsequenzen

- Ein Repo erzählt die ganze Geschichte (VM bis Deployment); leicht zu überblicken.
- Jede Ebene kann später eigene CI-Checks bekommen.
- GitOps-Tools (ArgoCD/Flux) können auf Unterpfade des Repos zeigen.
- Leere Ordner brauchen einen Platzhalter (`.gitkeep`), da Git sie sonst ignoriert.

## Alternativen

- **Polyrepo (getrennte Repos):** sinnvoll bei getrennten Berechtigungen/Teams,
  für ein Lern-/Portfolio-Projekt nur Fragmentierung ohne Gewinn.
- **Gliederung nach Anwendung:** vermischt Ebenen mit unterschiedlichem
  Lebenszyklus; verworfen.

## Offen / später

- Innenstruktur von `cluster/` folgt in Phase 5 (abhängig von ArgoCD vs. Flux).
- `live/` vs. `environments/` als Benennung ist Geschmackssache.
