# Remote state en S3 con lock en DynamoDB.
# Reemplazar 894196686263 por el bucket_name que imprime bootstrap/.
terraform {
  backend "s3" {
    bucket         = "teslo-two-tier-tfstate-894196686263"
    key            = "two-tier/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "teslo-two-tier-tflock"
    encrypt        = true
  }
}
