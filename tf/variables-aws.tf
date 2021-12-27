variable "region" {
  default = "ap-southeast-2"
}

variable "vpcCIDRblock" {
  default = "10.0.0.0/16"
}

variable "publicCIDRblock" {
  default = "10.0.128.0/18"
}

variable "privateCIDRblock" {
  default = "10.0.192.0/19"
}

variable "natCIDRblock" {
  default = "10.0.0.0/17"
}

variable "home_ip" {
  description = "Home IP address"
  type = string
}

variable "opa_az_count" {
  type = number
  description = "number of AZs to run OPA agent"
  default = 2
  validation {
    condition = var.opa_az_count >= 1 || var.opa_az_count >= 3
    error_message = "OPA AZ count should be between 1 to 3."
  }
}

variable "public_az_count" {
  type = number
  description = "number of AZs to run public subnets"
  default = 3
  validation {
    condition = var.public_az_count >= 1 || var.public_az_count >= 3
    error_message = "Public AZ count should be between 1 to 3."
  }
}

variable "jump-ami" {
  type = string
  description = "jump box linux ami"
  default = "ami-0f96495a064477ffb"
}
