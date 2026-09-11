terraform {
  backend "s3" {
    bucket       = "online-boutique-tfstate-858093957996"
    key          = "prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
