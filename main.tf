module "ec2" {
  source = "./modules/ec2"

  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0cb749514de13e708" -> null"
  sg_ids        = [aws_security_group.web_sg.id]
}
