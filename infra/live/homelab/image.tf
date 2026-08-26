# infra/live/homelab/images.tf
resource "proxmox_download_file" "debian13" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve2"

  url       = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-genericcloud-amd64.qcow2"

  # Integrität (empfohlen, passt zu deinem Supply-Chain-Fokus):
  # SHA512 aus https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS holen
  checksum           = "184761b0dad0f9ace02f9298050ca96ce3caa39a461a47706d47ff9698b59933918b91b40177fbd4d392f6446af8b4d18ecb94caca988169b19641606bf34003"
  checksum_algorithm = "sha512"

  overwrite = false
}
