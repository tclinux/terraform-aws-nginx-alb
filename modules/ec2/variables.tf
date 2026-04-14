variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "sg_ids" {
  type = list(string)
}
