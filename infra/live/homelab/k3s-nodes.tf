# infra/live/homelab/k3s-nodes.tf

data "local_file" "ssh_pub" {
  filename = pathexpand("~/.ssh/id_ed25519.pub")
}

locals {
  nodes = {
    "k3s-server-1" = { vm_id = 160, ip = "192.168.0.160/24" }
    "k3s-server-2" = { vm_id = 161, ip = "192.168.0.161/24" }
    "k3s-server-3" = { vm_id = 162, ip = "192.168.0.162/24" }
    "k3s-agent-1"  = { vm_id = 163, ip = "192.168.0.163/24" }
    "k3s-agent-2"  = { vm_id = 164, ip = "192.168.0.164/24" }
  }
}

module "k3s_nodes" {
  source   = "../../modules/vm"
  for_each = local.nodes

  name       = each.key
  vm_id      = each.value.vm_id
  ip_address = each.value.ip

  image_id       = proxmox_download_file.debian13.id
  ssh_public_key = trimspace(data.local_file.ssh_pub.content)
}

# Sicherer State-Umzug: server-1 wechselt nur die Adresse, wird NICHT neu gebaut
moved {
  from = proxmox_virtual_environment_vm.k3s_server_1
  to   = module.k3s_nodes["k3s-server-1"].proxmox_virtual_environment_vm.this
}

# Hook für Phase 3 (Ansible-Inventory): alle Node-IPs gesammelt
output "k3s_node_ips" {
  value = { for k, m in module.k3s_nodes : k => m.ipv4 }
}
