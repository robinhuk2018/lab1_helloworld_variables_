######################################################################
#   AWS PROVIDER
######################################################################
/* Configuring aws provider and version */
terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version =   "~>4.0"
    }
  }
}
  
/* Configuring aws region with variables information*/
provider "aws" {
  region = var.vaws_region
}

######################################################################
#   NETWORKING
######################################################################

/* Creating a VPC A with variables information*/
resource "aws_vpc" "raws_vpc_dev" {
  cidr_block = var.vaws_vpc_cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = true
  //This tag will add Name for VPC is VPC Dev
  tags = "${merge(var.vaws_resource_tags,{Name="VPC Dev"})}"
}

/* Creating public subnets with variables information */
 resource "aws_subnet" "raws_public_subnets" {
  vpc_id = aws_vpc.raws_vpc_dev.id
  count =length(var.vaws_public_subnet_cidr_blocks)
  availability_zone = element(var.vaws_az,count.index)
  cidr_block = element(var.vaws_public_subnet_cidr_blocks,count.index)
  tags = "${merge(var.vaws_resource_tags,{Name="Public Subnet ${count.index+1}"})}"
}

/* Creating private subnets with variables information */
 resource "aws_subnet" "raws_private_subnets" {
  vpc_id = aws_vpc.raws_vpc_dev.id
  count =length(var.vaws_private_subnet_cidr_blocks)
  availability_zone = element(var.vaws_az,count.index)
  cidr_block = element(var.vaws_private_subnet_cidr_blocks,count.index)
  tags = "${merge(var.vaws_resource_tags,{Name="Private Subnet ${count.index+1}"})}"
}

/* Creating Internet Gateway for VPC Dev */
resource "aws_internet_gateway" "raws_internet_gateway_dev" {
  vpc_id = aws_vpc.raws_vpc_dev.id
  tags = "${merge(var.vaws_resource_tags,{Name="Internet Gateway Dev"})}"
}

/* Creating Nat Gateway for 2 Private Subnets on 2 seperate AZ(a,b) in VPC Dev. 
Reruired: Creating 2 EIP for 2 NAT GATEWAY before to create 2 NAT GATEWAY */
/* Creating 2 EIP for 2 NAT Gateway */
resource "aws_eip" "raws_eip" {
  vpc = true
  count =length(var.vaws_private_subnet_cidr_blocks)
  tags = "${merge(var.vaws_resource_tags,{Name="EIP NatGW ${count.index+1}"})}"
  depends_on = [
    aws_internet_gateway.raws_internet_gateway_dev
  ]
}
/* Creating 2 Nat Gateway on 2 public subnets and assign 2EIP for each */
resource "aws_nat_gateway" "raws_nat_gateway" {
  count = length(var.vaws_private_subnet_cidr_blocks)
  allocation_id = aws_eip.raws_eip[count.index].id
  subnet_id = aws_subnet.raws_public_subnets[count.index].id
  tags = "${merge(var.vaws_resource_tags,{Name="Nat Gateway ${count.index+1}"})}"

  depends_on = [
    aws_eip.raws_eip,
    aws_subnet.raws_public_subnets,
    aws_internet_gateway.raws_internet_gateway_dev
  ]
}

/* Creating Route Table to allow 2 public subnets to route traffic to internet and versus */
resource "aws_route_table" "raws_rtb_internet" {
  vpc_id = aws_vpc.raws_vpc_dev.id
  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.raws_internet_gateway_dev.id
  }
  tags = "${merge(var.vaws_resource_tags,{Name="Internet"})}"
  depends_on = [
    aws_vpc.raws_vpc_dev
  ]
}

/* Creating association public subnets into raws_rtb_internet */
resource "aws_route_table_association" "raws_rtb_internet_association" {
  route_table_id = aws_route_table.raws_rtb_internet.id
  count = length(var.vaws_public_subnet_cidr_blocks)
  subnet_id = aws_subnet.raws_public_subnets[count.index].id
  depends_on = [
    aws_route_table.raws_rtb_internet
  ]
}

/* Creating 2 Route Table for 2 private subnets access internet through Nat Gateway 
to download and update software as needed */
resource "aws_route_table" "raws_rtb_natgw" {
  vpc_id = aws_vpc.raws_vpc_dev.id
  count = length(var.vaws_private_subnet_cidr_blocks)
  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.raws_nat_gateway[count.index].id
  }
  tags = "${merge(var.vaws_resource_tags,{Name="Nat GW ${count.index+1}"})}"
  depends_on = [
    aws_vpc.raws_vpc_dev
  ]
}

/* Creating association 2 seperate private subnets into 2 seperate raws_rtb_natgw */
resource "aws_route_table_association" "raws_rtb_natgw_association" {
  count = length(var.vaws_private_subnet_cidr_blocks)
  route_table_id = aws_route_table.raws_rtb_natgw[count.index].id
  subnet_id = aws_subnet.raws_private_subnets[count.index].id
  depends_on = [
    aws_route_table.raws_rtb_natgw
  ]
}

/* Create 2xWEBSERVER instance on 2 private subnet with basic setup for web server*/
/* Create Security Group allow ALB acess to 2xwebserver on port 80 */
resource "aws_security_group" "raws_sg_webservers" {
  name = "allow http webservers"
  description = "Allow http inbound traffic from VPC"
  vpc_id = aws_vpc.raws_vpc_dev.id
  ingress {
    description      = "HTTP from ALB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.vaws_vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = "${merge(var.vaws_resource_tags,{Name="sg-webservers-http"})}"

  depends_on = [
    aws_vpc.raws_vpc_dev
  ]
}
/* Create 2 webservers on 2 private subnet */
resource "aws_instance" "raws_ec2_webservers" {
  count = length(var.vaws_private_subnet_cidr_blocks)
  ami           = "ami-089a545a9ed9893b6"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.raws_private_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.raws_sg_webservers.id]
  user_data = file("webserver.conf")

  tags = "${merge(var.vaws_resource_tags,{Name="webservers ${count.index + 1}"})}"
  
  #Wait Nat Gateway, Nat route table, nat route association are ready before create the aws_instance 
  #to make sure that instance can access internet to run User data configuration
  depends_on = [
    aws_nat_gateway.raws_nat_gateway,
    aws_route_table.raws_rtb_natgw,
    aws_route_table_association.raws_rtb_internet_association
  ]
}
/* Create APPLICATION LOAD BALANCING */
/* Create Security Group for Application Load Balancing */
resource "aws_security_group" "raws_sg_alb" {
  name = "allow http alb"
  description = "Allow http inbound traffic"
  vpc_id = aws_vpc.raws_vpc_dev.id
  ingress {
    description      = "HTTP from Internet"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = "${merge(var.vaws_resource_tags,{Name="sg-alb-http"})}"

  depends_on = [
    aws_vpc.raws_vpc_dev
  ]
}

/* Create Application Load Balancing */
resource "aws_lb" "raws_alb" {
  name = "alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.raws_sg_alb.id]
  #subnets = [aws_subnet.raws_public_subnets[0].id, aws_subnet.raws_public_subnets[1].id]
  subnets = [for public_subnets in aws_subnet.raws_public_subnets : public_subnets.id]

  tags = var.vaws_resource_tags
  depends_on = [
    aws_security_group.raws_sg_alb
  ]
}

/* Create Target Group for 2 WebServer in Private Subnet on 2AZ */
resource "aws_lb_target_group" "raws_tg_webservers" {
  name = "tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.raws_vpc_dev.id
}

/* Create Target Group Listener */
resource "aws_lb_listener" "raws_alb_listener" {
  load_balancer_arn = aws_lb.raws_alb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type =  "forward"
    target_group_arn = aws_lb_target_group.raws_tg_webservers.arn
  }
}
/* Create target group attachment */
resource "aws_lb_target_group_attachment" "raws_alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.raws_tg_webservers.arn
  count =length(aws_instance.raws_ec2_webservers)
  target_id = aws_instance.raws_ec2_webservers[count.index].id
  port = 80
}


