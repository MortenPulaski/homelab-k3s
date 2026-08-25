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
variable "dns_domain" {
  type    = string
  default = "marpal-it.de"
}
variable "dns_servers" {
  type    = list(string)
  default = ["192.168.0.145"]
}
variable "username" {
  type    = string
  default = "ops"
}
