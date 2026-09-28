# Remote state in S3 with native state locking (Terraform >= 1.10, no DynamoDB needed).
# The bucket name must be globally unique, so it is NOT hardcoded here. Pass it at init time:
#
#   terraform init -backend-config="bucket=<your-state-bucket>"
terraform {
  backend "s3" {
    key          = "jenkins/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
