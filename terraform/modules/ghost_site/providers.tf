provider "aws" {
  default_tags {
    tags = {
      environment = var.environment
    }
  }
}
