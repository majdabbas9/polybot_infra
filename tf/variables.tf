variable "region" {
  description = "AWS region"
  type        = string
}
variable "username" {
    description = "Username for the EC2 instance"
    type        = string
}
variable "azs" {
  description = "Availability zones"
  type        = list(string)
}
variable "ami" {
    description = "AMI ID for the EC2 instance"
    type        = string
}
variable "key_pair_name" {
    description = "SSH key name for the EC2 instance"
    type        = string
}
