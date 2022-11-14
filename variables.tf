######################################################################
#   VARIABLE FOR REGION and AVAILABILITY ZONE                           
######################################################################
/* AWS Region */
variable "vaws_region" {
    description = "AWS Region"
    type = string
    default = "us-east-2"
}

/* AWS Availability Zone */
 variable "vaws_az" {
  description = "AWS Availability Zone"
  type = list(string)
  default = [ 
        "us-east-2a",
        "us-east-2b",
        "us-east-2c"
        ]
} 
######################################################################
#   VARIABLE FOR RESOURCE TAGS 
######################################################################
/* Resource tags for 123cloudjourney-alpha in dev environment*/
variable "vaws_resource_tags" {
  description = "Tags to set for all resources"
  type = map(string)
  default = {
    project = "123cloudjourney-alpha",
    environment ="dev",
    owner = "jack@123cloudjourney.com"
  }
}

######################################################################
#   VARIABLE FOR NETWORKING
######################################################################
/* VPC CIDR Block */
variable "vaws_vpc_cidr_block" {
  description = "CIDR block for VPC"
  type = string
  default = "10.0.0.0/16"
}

/* Public Subnet CIDR Blocks*/
variable "vaws_public_subnet_cidr_blocks" {
  description = "Public subnet blocks"
  type = list(string)
  default = [ 
        "10.0.0.0/24",
        "10.0.1.0/24" 
        ]
}

/* Private Subnet CIDR */
variable "vaws_private_subnet_cidr_blocks" {
  description = "Private subnet blocks"
  type = list(string)
    default = [ 
        "10.0.20.0/24",
        "10.0.21.0/24" 
        ]
}

/* Auto-assign public IPv4 address */
variable "vaws_auto_assign_public_ipaddress" {
  description = "Enable auto-assign public ip address"
  type = bool
  default = true
}