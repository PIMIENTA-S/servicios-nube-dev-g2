terraform {
  backend "s3" {
    bucket       = "tfstate-serviciosnube-angel-2025"
    key          = "nube/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "terraform-prod"
  }
}
