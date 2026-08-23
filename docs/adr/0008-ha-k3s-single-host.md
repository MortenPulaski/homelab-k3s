# ADR-0008: HA-k3s-Cluster auf einem einzelnen Proxmox-Host

- **Status:** akzeptiert
- **Datum:** 2026-08-23

## Kontext

k3s unterstützt echtes HA über mehrere Server-Nodes mit embedded etcd
(Quorum ab 3 Nodes). Für den Lerneffekt (etcd-Quorum, Leader-Election,
rollierende Updates ohne Downtime) ist dieses Muster gewünscht.

Alle VMs laufen jedoch auf **einem einzigen Proxmox-Host** (i7-13700T,
64 GB RAM, ZFS, ausreichend NVMe-Kapazität). Ressourcen sind kein
limitierender Faktor – die Frage ist rein strukturell: Schützt eine
HA-Topologie hier tatsächlich vor Ausfällen, oder täuscht sie Redundanz
nur vor?

## Entscheidung

**HA-Topologie trotz Single-Host**, mit explizit dokumentiertem Trade-off:

- 3 k3s-Server-Nodes (embedded etcd) + 2 k3s-Agent-Nodes
- Statische IP-Vergabe via cloud-init (siehe `docs/STATUS.md`, Abschnitt
  „Umgebung")
- **kube-vip** als virtuelle IP für den k3s-API-Server (`192.168.0.170`),
  damit Clients/`kubectl` nicht fest an einen einzelnen Server-Node
  gebunden sind

Die HA-Mechanik (etcd-Quorum, VIP-Failover) schützt vor: Ausfall eines
einzelnen VM-Betriebssystems, eines k3s-Prozesses, eines fehlerhaften
Deployments, geplanten Neustarts/Wartung einzelner Nodes.

Sie schützt **nicht** vor: Ausfall des Proxmox-Hosts selbst (Hardware-
Defekt, Stromausfall) – in diesem Fall fällt der gesamte Cluster
gleichzeitig aus, da alle Nodes auf demselben physischen System liegen.

## Konsequenzen

- Lerneffekt für produktionsrelevante HA-Konzepte (Quorum, VIP-Failover,
  Node-Draining) ist gegeben, obwohl echte Hochverfügbarkeit (mehrere
  physische Hosts) nicht vorliegt.
- Der Proxmox-Host bleibt Single Point of Failure auf Infrastruktur-
  Ebene – bewusst akzeptiert, kein Widerspruch zum HA-Design auf
  k3s-Ebene, sondern eine andere Schutzebene.
- Höherer Ressourcenbedarf (5 statt 1–2 VMs) – bei vorhandener Kapazität
  kein Problem.
- Spätere Erweiterung auf mehrere physische Hosts (echtes HA) wäre eine
  reine Infrastruktur-Erweiterung, keine Änderung am k3s-/kube-vip-Design.

## Alternativen

- **Single-Node k3s:** einfachster Einstieg, aber kein Lerneffekt für
  HA-Mechanismen – verworfen, da HA-Konzepte explizites Lernziel sind.
- **1 Server + N Agents (kein HA):** reduziert Komplexität, verzichtet
  aber auf etcd-Quorum/Leader-Election als Lerninhalt – verworfen.
- **Mehrere physische Hosts:** würde den strukturellen SPOF beseitigen,
  ist aber im aktuellen Homelab-Kontext (ein Host vorhanden) nicht
  umsetzbar. Bleibt als möglicher späterer Ausbauschritt im Hinterkopf.
