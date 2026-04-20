variable "ami" {}
variable "web_sg_id" {}
variable "subnets" {
  type = list(string)
}
variable "target_group_arn" {}
variable "key_name" {}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
variable "instance_profile_name" {
  type = string
}
