# infra/modules/vm/main.tf

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  on_boot   = var.on_boot

  agent { enabled = var.agent_enabled }
  stop_on_destroy = true

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = "lab"
    import_from  = var.image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  initialization {
    datastore_id = "lab"

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      username = var.username
      keys     = [var.ssh_public_key]
    }
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }
}
