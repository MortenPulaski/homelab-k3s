terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://pve2.marpal-it.de"
  # api_token wird NICHT hier eingetragen, sondern über die
  # Umgebungsvariable PROXMOX_VE_API_TOKEN aus secrets.sops.yaml geladen
  # (von mise automatisch bereitgestellt)
}
