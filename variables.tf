variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_list" {
  description = "List of VPC to create"
  type        = map(any)
  default = {
    dev = {
      vpc_name        = "dev"
      cidr_block = "10.0.3.0/24"
      tags = {
        name = "Dev-VPC"
      }
    }
    shared = {
      vpc_name        = "shared"
      cidr_block = "10.0.2.0/24"
      tags = {
        name = "Shared-VPC"
      }
    }
    prod = {
      vpc_name        = "prod"
      cidr_block = "10.0.1.0/24"
      tags = {
        name = "Prod-VPC"
      }
    }
    mgmt = {
      vpc_name        = "mgmt"
      cidr_block = "10.0.0.0/24"
      tags = {
        name = "Mgmt-VPC"
      }
    }
    transit = {
      vpc_name        = "transit"
      cidr_block = "10.0.4.0/23"
      tags = {
        name = "Transit-VPC"
      }
    }
  }
}