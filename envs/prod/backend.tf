terraform {
  backend "s3" {
    bucket       = "novasphere-tfstate-hbq"
    key          = "novasphere/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
