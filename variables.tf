variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_list" {
  description = "List of VPC to create"
  type        = map(any)
  default = {
    dev = {
      vpc        = "dev"
      cidr_block = "10.0.3.0/24"
      tags = {
        name = "Dev-VPC"
      }
    }
    shared = {
      vpc        = "shared"
      cidr_block = "10.0.2.0/24"
      tags = {
        name = "Shared-VPC"
      }
    }
    prod = {
      vpc        = "prod"
      cidr_block = "10.0.1.0/24"
      tags = {
        name = "Prod-VPC"
      }
    }
    mgmt = {
      vpc        = "mgmt"
      cidr_block = "10.0.0.0/24"
      tags = {
        name = "Mgmt-VPC"
      }
    }
    transit = {
      vpc        = "transit"
      cidr_block = "10.0.4.0/23"
      tags = {
        name = "Transit-VPC"
      }
    }
  }
}