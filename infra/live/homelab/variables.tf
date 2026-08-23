variable "state_encryption_passphrase" {
  type        = string
  sensitive   = true
  description = "Passphrase für die OpenTofu-State-Verschlüsselung (PBKDF2)"
}
