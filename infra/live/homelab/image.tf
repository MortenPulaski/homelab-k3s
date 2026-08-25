# infra/live/homelab/images.tf
resource "proxmox_download_file" "debian13" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve2"

  url       = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-genericcloud-amd64.qcow2"

  # Integrität (empfohlen, passt zu deinem Supply-Chain-Fokus):
  # SHA512 aus https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS holen
  checksum           = "77429b411b39b43f914dc9d14bf34aa315489a1a12b5429f72e5b483bdda23c65698d33443c85d3f3ad7c3a0828ae60845406d6b99646342554d17abae29c2a3"
  checksum_algorithm = "sha512"

  overwrite = false
}
