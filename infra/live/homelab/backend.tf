terraform {
  backend "s3" {
    bucket = "tofu-state"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1" # Dummy – RustFS ist nicht AWS

    endpoints = {
      s3 = "https://s3.marpal-it.de"
    }

    use_path_style = true  # self-hosted S3: Path-Style statt vhost-DNS
    use_lockfile   = false # kein natives Locking (RustFS + solo), siehe ADR-0006

    # Non-AWS: AWS-spezifische Prüfungen abschalten
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
