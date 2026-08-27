# infra/modules/vm/variables.tf

variable "name" { type = string }
variable "vm_id" { type = number }
variable "ip_address" {
  type        = string
  description = "CIDR, z. B. 192.168.0.160/24"
}
variable "agent_enabled" {
  description = "QEMU-Guest-Agent-Kanal. Erst true, nachdem Ansible den Agent installiert hat (zweistufiger Bring-up, ADR-0009)."
  type        = bool
  default     = false # sicherer Default fürs Erst-Deployment
}

variable "on_boot" {
  description = "Ob die VM beim Proxmox-Host-Boot automatisch startet (defaults to true beim Provider, hier bewusst false fürs Lern-Setup)."
  type        = bool
  default     = false
}

variable "startup_order" {
  description = "Proxmox Start/Shutdown order (Priorität, aufsteigend gestartet, absteigend gestoppt)."
  type        = number
  default     = null
}

variable "startup_up_delay" {
  description = "Sekunden Wartezeit, bevor die nächste Prioritätsstufe startet."
  type        = number
  default     = null
}

# von der Live-Ebene durchgereicht (Modul greift nicht selbst ins Dateisystem)
variable "image_id" { type = string }
variable "ssh_public_key" { type = string }

# umgebungsweite Konstanten mit Defaults
variable "cores" {
  type    = number
  default = 2
}
variable "memory" {
  type    = number
  default = 4096
}
variable "disk_size" {
  type    = number
  default = 20
}
variable "node_name" {
  type    = string
  default = "pve2"
}
variable "bridge" {
  type    = string
  default = "vmbr0"
}
variable "gateway" {
  type    = string
  default = "192.168.0.1"
}
variable "dns_servers" {
  type    = list(string)
  default = ["192.168.0.145"]
}
variable "dns_domain" {
  type    = string
  default = " "
}
variable "username" {
  type    = string
  default = "ops"
}
