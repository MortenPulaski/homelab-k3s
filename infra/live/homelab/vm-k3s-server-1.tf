# infra/live/homelab/vm-k3s-server-1.tf   (erst mal EINE VM, flach)

data "local_file" "ssh_pub" {
  filename = pathexpand("~/.ssh/id_ed25519.pub") # ← an deinen Key anpassen
}

resource "proxmox_virtual_environment_vm" "k3s_server_1" {
  name      = "k3s-server-1"
  node_name = "pve2"
  vm_id     = 160

  agent { enabled = false }
  stop_on_destroy = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "lab" # ZFS
    import_from  = proxmox_download_file.debian13.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  initialization {
    datastore_id = "lab" # NICHT default local-lvm

    ip_config {
      ipv4 {
        address = "192.168.0.160/24"
        gateway = "192.168.0.1" # ← bestätigen
      }
    }

    dns {
      domain  = "marpal-it.de"
      servers = ["192.168.0.145"] # ← AdGuard-Home-IP
    }

    user_account {
      username = "ops" # ← Wunsch-User
      keys     = [trimspace(data.local_file.ssh_pub.content)]
    }
  }

  network_device {
    bridge = "vmbr0" # ← bestätigen
  }

  operating_system {
    type = "l26"
  }
}
