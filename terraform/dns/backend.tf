terraform {
  backend "s3" {
    bucket       = "online-boutique-tfstate-900182162489"
    key          = "dns/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
