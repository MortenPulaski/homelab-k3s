# ADR-0010: Config-Management mit Ansible & kube-vip-Installationsmuster

- **Status:** akzeptiert
- **Datum:** 2026-08-27

## Kontext

ADR-0009 legte die Grenze zwischen Tofu (Provisioning: VM, Disk, Netz,
Identität) und Ansible (Konfiguration: Pakete, Dienste, k3s-Prep) fest, aber
nur für die VM-Ebene. Mit dem k3s-Bootstrap (Phase 3) kam eine dritte Ebene
dazu: **Cluster-interne Workloads** (kube-vip als DaemonSet). Für diese
Ebene stellte sich eine eigene Grundsatzfrage, die ADR-0009 nicht abdeckt:
Gehört ein Kubernetes-Manifest wie kube-vip zum Ansible-Bootstrap (z. B. als
Boot-Zeit-Manifest, das k3s beim ersten Start selbst einliest), oder ist es
ein eigener, nachgelagerter Schritt gegen den laufenden Cluster?

Diese Frage wurde nicht theoretisch entschieden, sondern über zwei
gescheiterte Versuche empirisch geklärt (vollständige Root-Cause-Analyse in
`docs/incidents/incidents.md`, INC-001 und INC-002):

- **INC-001:** kube-vip als Boot-Zeit-Manifest
  (`/var/lib/rancher/k3s/server/manifests/`) führte nach einigen Stunden
  Laufzeit zu intermittierendem IPv4-Verlust der Node-eigenen Adresse
  (Verdacht: `hostNetwork: true` + `NET_ADMIN`-Capability in Kombination mit
  dynamischer Interface-Erkennung, nicht abschließend verifiziert). Beim
  Boot-Zeit-Muster ist das Verhalten des Pods vor dem ersten `kubectl get
  pods` unsichtbar – kein Beobachtungsfenster vor dem produktiven Einsatz.
- **INC-002:** kube-vip per `kubectl apply` gegen den laufenden Cluster
  (Fix aus INC-001) löste einen zweiten, unabhängigen Vorfall aus:
  `svc_enable: true` ließ kube-vip mit k3s' eingebautem ServiceLB (Klipper)
  um dieselben LoadBalancer-Service-IPs konkurrieren, was zu
  ARP-Fehlleitung und etcd-Quorum-Verlust führte.

## Entscheidung

### 1. Drei-Ebenen-Werkzeuggrenze (Ergänzung zu ADR-0009)

- **Tofu:** VM-Provisioning (unverändert, ADR-0009).
- **Ansible:** Node-Konfiguration + k3s-Installation selbst (Pakete, tls-san-
  Config, `k3s server`/`k3s agent` Installer-Skript).
- **`kubectl apply` gegen den laufenden Cluster:** alles, was **innerhalb**
  des Kubernetes-API läuft (Cluster-Workloads wie kube-vip), explizit **nicht**
  als Ansible-Task und **nicht** als k3s-Boot-Zeit-Manifest.

Begründung: Sobald ein Manifest von Kubernetes selbst verwaltet wird (Pods,
DaemonSets), ist `kubectl`/die Kubernetes-API das native, beobachtbare
Werkzeug dafür – nicht ein zusätzlicher Ansible- oder Boot-Zeit-Umweg, der
den eigentlichen Kubernetes-Reconciliation-Loop umgeht.

### 2. kube-vip: nachträglicher `kubectl apply`, kein Boot-Zeit-Manifest

Nach INC-001 endgültig verworfen: kube-vip-Manifeste in
`/var/lib/rancher/k3s/server/manifests/` vor `--cluster-init` zu kopieren.
Stattdessen: `cluster/kube-vip/{rbac,daemonset}.yaml` liegen im Repo, werden
aber **manuell** per `kubectl apply` nach erfolgreichem Node-Bring-up
angewendet – mit Pod-Status/Logs live beobachtbar
(`kubectl get pods -n kube-system -l name=kube-vip-ds -w`), statt unsichtbar
beim ersten Boot.

### 3. kube-vip-Scope vorerst auf Control-Plane beschränkt

Nach INC-002: `svc_enable: "false"` im DaemonSet-Manifest. kube-vip ist
aktuell **ausschließlich** für die API-Server-VIP zuständig (`cp_enable`),
nicht für `Service type=LoadBalancer`. Die Zuständigkeit für
LoadBalancer-Services (Klipper beibehalten vs. MetalLB vs. kube-vip
`--services` erneut mit sauberem Fix) wird bewusst **nicht** hier
entschieden, sondern zusammen mit dem Ingress-Konzept in Phase 4.

Zusätzlich: `nodeSelector: node-role.kubernetes.io/control-plane: "true"` –
das DaemonSet läuft nur auf den 3 Server-Nodes, nicht auf den Agents (die an
der API-Server-VIP-Leader-Election ohnehin nicht teilnehmen sollten).

## Konsequenzen

- **Reproduzierbarkeit bleibt gegeben, aber zweistufig:** Ein Von-Null-Neubau
  ist keine einzelne Ansible-Ausführung mehr, sondern eine dokumentierte
  Befehlskette (`tofu apply` → `ansible-playbook site.yml --tags k3s` →
  `kubectl apply -f cluster/kube-vip/`), siehe „Reproduzierbarer
  Node-Bring-up" in `docs/STATUS.md`. Bewusster Trade-off: ein manueller
  `kubectl apply`-Schritt zugunsten von Beobachtbarkeit, statt vollständiger
  Automatisierung in einem einzigen Playbook-Lauf.
- **Spätere Automatisierung möglich, aber vertagt:** Der manuelle
  `kubectl apply`-Schritt könnte später über das `kubernetes.core.k8s`-
  Ansible-Modul oder GitOps (Phase 5, ArgoCD/Flux) automatisiert werden.
  Bewusst nicht jetzt, solange kube-vip als noch nicht vollständig
  ausgereiftes Muster im eigenen Setup gilt (zwei Incidents in Folge).
- **tls-san-Sonderfall bleibt in Ansible, nicht in kubectl:** Die
  `tls-san`-Config (`/etc/rancher/k3s/config.yaml`) ist eine k3s-Server-
  Konfiguration, kein Kubernetes-Objekt – bleibt daher folgerichtig in der
  Ansible-Rolle `k3s_server`, nicht Teil dieser Werkzeuggrenze.
- **Scope-Entscheidung (Punkt 3) erzeugt bewusst offene Folgefrage:**
  Traefik/LoadBalancer-Zuständigkeit ist in `docs/STATUS.md` unter „Offen"
  als Phase-4-Vorarbeit vermerkt – kein Widerspruch zum Phase-3-Abschluss,
  da das ursprüngliche Phase-3-Ziel (HA-API-VIP) vollständig erreicht ist.
- **Kosten der empirischen Klärung:** Beide Incidents zusammen kosteten
  mehrere Stunden Debugging inkl. eines vollständigen Neuaufbaus
  (`tofu destroy` + Bring-up von Null). Der Lerneffekt (QEMU-Guest-Agent als
  Diagnose-Kanal bei Netzwerkausfall, ARP/ServiceLB-Interaktion,
  Leader-Election-Fallstricke) ist dokumentiert und wiederverwendbar für
  künftige Kubernetes-Netzwerk-Debugging-Situationen.

## Alternativen

- **Boot-Zeit-Manifest beibehalten, Ursache in INC-001 weiter debuggen:**
  verworfen – das offizielle k3s+kube-vip-Muster ist für dieses Setup nicht
  reproduzierbar stabil; Debugging-Aufwand stand in keinem Verhältnis zum
  Nutzen (marginal schnellerer Bring-up) gegenüber dem gewählten Muster.
- **`--disable servicelb` sofort statt `svc_enable: false`:** verworfen für
  jetzt – hätte einen erneuten k3s-Reinstall auf allen 3 Servern erfordert
  (Install-Time-Flag, nicht per Config-Reload nachrüstbar) und Traefik ohne
  sofortigen Ersatz von seiner LoadBalancer-IP getrennt. Größerer Eingriff
  ohne unmittelbaren Bedarf – siehe Punkt 3 oben, Entscheidung nach Phase 4
  vertagt.
- **kube-vip komplett verwerfen, Single-Server-API-Zugriff akzeptieren:**
  verworfen – widerspricht dem expliziten HA-Lernziel aus ADR-0008; ein
  Server als SPOF für `kubectl`-Zugriff wäre ein Rückschritt gegenüber der
  bereits vorhandenen etcd-HA.
- **Helm statt raw Manifeste für kube-vip:** nicht gewählt für den
  Ersteinsatz – rohe Manifeste machten die Fehlersuche in INC-001/INC-002
  direkter nachvollziehbar (kein zusätzlicher Templating-Layer). Für Phase 4
  (wenn ohnehin Helm für andere Workloads eingeführt wird) neu zu bewerten.

## Bezug

- Vollständige Root-Cause-Analysen: `docs/incidents/incidents.md`
  (INC-001, INC-002)
- Werkzeuggrenze VM-Ebene (Tofu/Ansible): ADR-0009
- HA-Topologie-Begründung (warum kube-vip überhaupt nötig ist): ADR-0008
