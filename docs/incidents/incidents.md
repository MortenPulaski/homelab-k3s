# Incident-Log

Ungeplante Service-Unterbrechungen mit Root-Cause-Analyse. Dient als
Nachschlagewerk für „was haben wir daraus gelernt", getrennt vom laufenden
Fortschritt in `docs/STATUS.md`.

---

## INC-001: kube-vip Boot-Zeit-Manifest – IPv4-Verlust des Nodes

- **Datum:** 2026-08-26
- **Schweregrad:** Hoch (Cluster komplett über IPv4 unerreichbar)
- **Status:** Behoben (durch Architekturänderung, siehe „Fix" unten)

### Was passiert ist
kube-vip-RBAC + DaemonSet-Manifest vor `--cluster-init` nach
`/var/lib/rancher/k3s/server/manifests/` kopiert (offizielles k3s+kube-vip-
Boot-Zeit-Muster). Nach einigen Stunden Laufzeit verlor `srv-1`
intermittierend seine **eigene** IPv4-Adresse (nicht nur die VIP) – Cluster
über IPv4 unerreichbar, API-Server antwortete zeitweise gar nicht mehr
(`ServiceUnavailable`).

### Root Cause
Nicht abschließend verifiziert. Verdacht: `hostNetwork: true` +
`NET_ADMIN`-Capability des kube-vip-Pods in Kombination mit dynamischer
Interface-Erkennung. Reproduzierbar mit dem Boot-Zeit-Manifest, verschwunden
nach komplettem Neuaufbau ohne kube-vip (30+ min stabile IPv4/SSH-Verbindung
bestätigt).

### Fix
kube-vip wird nicht mehr als Boot-Zeit-Manifest installiert, sondern
nachträglich per `kubectl apply` gegen den laufenden Cluster – beobachtbar,
mit Pod-Status/Logs live statt unsichtbar beim ersten Boot.

### Diagnose-Weg
Standard-SSH/Netzwerk-Debugging, da IPv4 zeitweise komplett weg war –
Proxmox-Konsole zur Erstdiagnose genutzt.

---

## INC-002: kube-vip `--services` vs. k3s ServiceLB – ARP-Konflikt

- **Datum:** 2026-08-26
- **Schweregrad:** Hoch (etcd-Quorum-Verlust, API-Server hängt)
- **Status:** Behoben (2026-08-27, siehe „Fix" unten, verifiziert)

### Was passiert ist
Nach dem Fix aus INC-001: kube-vip-RBAC + DaemonSet (`v1.2.0`,
`--controlplane --services --arp`) per `kubectl apply` gegen den laufenden
Cluster angewendet. Kurz darauf: Netzwerk/SSH zunehmend unzuverlässig,
mehrfache CrashLoopBackOff-Zyklen von kube-vip.

### Root Cause
- k3s installiert standardmäßig Traefik als `Service type=LoadBalancer`.
- k3s' eingebautes ServiceLB (Klipper) weist solchen Services **die IPs aller
  berechtigten Nodes** als External-IPs zu (Standardverhalten).
- kube-vip mit `--services` (`svc_enable: true`) beobachtet dieselben
  LoadBalancer-Services und übernimmt deren External-IP-Liste zur
  ARP-Advertisement. Da es **eine globale Leader-Election** gibt (nicht pro
  Service), bindet der gewählte Leader-Node **alle** diese Adressen lokal –
  beobachtet: sämtliche Server- und Agent-IPs (`.160`–`.164`) auf dem
  jeweiligen Leader.
- Folge: ARP-Antworten für fremde Node-IPs, dadurch fehlgeleiteter
  etcd-Peer-Traffic (Port 2380) zwischen den Servern → Quorum-Verlust →
  API-Server bleibt im Start hängen (`ServiceUnavailable`, `no leader`).

### Diagnose-Weg
QEMU-Guest-Agent (`qm guest exec <vmid> -- …` auf `pve2`) – läuft über
virtio-serial, umgeht Netzwerk/ARP vollständig, führt Befehle direkt als root
aus. Damit: Adressen inspiziert/bereinigt (`ip addr del … dev eth0`),
kube-vip-Container gezielt gestoppt (`k3s crictl stop`), DaemonSet gelöscht.

### Zwischenentscheidung
Nach anhaltender Instabilität (jeder CrashLoopBackOff-Zyklus schrieb die
Adressen erneut): vollständiger Neuaufbau statt Weiter-Debugging im laufenden
System (`tofu destroy` + Bring-up von Null).

### Fix
`svc_enable: "false"` in `cluster/kube-vip/daemonset.yaml` (statt
`--disable servicelb` beim k3s-Server-Start – kleinerer Eingriff, kein
Reinstall nötig). kube-vip kümmert sich damit nur noch um `cp_enable`
(API-Server-VIP), rührt keine `Service type=LoadBalancer`-Objekte mehr an.
Klipper/ServiceLB bleibt unverändert für Traefik zuständig; Zuständigkeit für
LoadBalancer-Services (Klipper vs. MetalLB vs. kube-vip) wird bewusst erst in
Phase 4 zusammen mit dem Ingress-Konzept neu entschieden.

**Zusätzlich gefunden (unabhängig vom ARP-Konflikt):** RBAC (`rbac.yaml`)
war nie scharf angewendet worden (nur `--dry-run=server` getestet) –
DaemonSet-Controller konnte deshalb keine Pods erzeugen (`serviceaccount
"kube-vip" not found`). Nach scharfem `kubectl apply -f rbac.yaml` liefen
die Pods sofort hoch.

**Zusätzlich ergänzt:** `nodeSelector:
node-role.kubernetes.io/control-plane: "true"` in `daemonset.yaml` –
DaemonSet lief zunächst auf allen 5 Nodes (auch Agents), was funktional
unschädlich, aber unnötig war.

### Verifikation
- VIP (`192.168.0.170`) sitzt nach Leader-Election auf genau einem
  Server-Node, `kubectl --server=https://192.168.0.170:6443` funktioniert.
- Kontrollierter Cluster-Reboot (`shutdown.yml` + Massenstart via
  Proxmox-`startup_order`) überstanden, VIP kehrt zurück.
- Harter Node-Ausfall simuliert (`qm stop` auf dem VIP-Leader): Failover zu
  neuem Leader in wenigen Sekunden (passend zu `vip_leaseduration: 5`/
  `vip_renewdeadline: 3`), VIP-Zugriff durchgehend funktionsfähig, Node-Rejoin
  nach `qm start` sauber (`/healthz` → `ok`).

---

## Nebenbefund (kein eigenständiges Incident, im Rahmen von INC-002 entdeckt)

`debian-13-genericcloud-amd64.qcow2` unter `.../trixie/latest/` ist ein
rollierender Pointer (ändert sich pro Debian-Point-Release); die in
`image.tf` hinterlegte SHA512-Checksum war dadurch veraltet (`checksum
mismatch` beim Neuaufbau). Zusätzlich zeitweiser Ausfall von
`cloud.debian.org` selbst während des Vorfalls. Fix: aktuellen Hash aus
`SHA512SUMS` neu gezogen. **Noch offen:** Checksum dynamisch per `data
"http"`-Source statt hartkodiert beziehen, oder auf eine datierte
Build-URL wechseln.
