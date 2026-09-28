# Remote state in S3 with native state locking (Terraform >= 1.10, no DynamoDB needed).
# Bucket and key are passed at init time (the Jenkinsfile does this for you):
#
#   terraform init \
#     -backend-config="bucket=<your-state-bucket>" \
#     -backend-config="key=eks/<environment>/terraform.tfstate"
#
# One key per environment, so dev/test/prod never overwrite each other.
terraform {
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
