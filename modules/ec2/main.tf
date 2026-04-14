resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.sg_ids
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    amazon-linux-extras install -y nginx1
    systemctl start nginx
    systemctl enable nginx
  EOF

  tags = {
    Name = "terraform-nginx"
  }
}
