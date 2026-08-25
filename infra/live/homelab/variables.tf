variable "state_encryption_passphrase" {
  type        = string
  sensitive   = true
  description = "Passphrase für die OpenTofu-State-Verschlüsselung (PBKDF2)"
}

variable "agent_enabled" {
  description = "QEMU-Guest-Agent-Kanal der k3s-Nodes. Steady state: true. Für einen Von-Null-Neubau in Stufe 1 per '-var agent_enabled=false' übersteuern (ADR-0009)."
  type        = bool
  default     = true
}
