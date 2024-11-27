variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = ["ap-northeast-2a"]
}

variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type        = string
  default     = "192.168.0.0/16"
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}
