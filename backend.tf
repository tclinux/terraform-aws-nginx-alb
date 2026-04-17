terraform {
  backend "s3" {
    bucket         = "terraform-state-net4.net"  # ←自分の名前に変更
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
