# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# Terraform Data Block - Lookup Ubuntu 20.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}
#Creating the Transit Gateway for the Region
resource "aws_ec2_transit_gateway" "tf_lab_tgw" {
  description = "The TGW for tf-lab"
  tags = {
    Terraform = "true"
  }
}
resource "aws_ec2_transit_gateway_route" "tgw_defualt" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.transit_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
# Creating SSH private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "priviate_key.pem"
}
# Creating the AWS Key pair from the private key
resource "aws_key_pair" "generated" {
  key_name   = "TFLabKey"
  public_key = tls_private_key.generated.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}



#Define the Managment VPC
resource "aws_vpc" "mgmt_vpc" {
  cidr_block = "10.0.0.0/24"
  tags = {
    Name        = "mgmt_vpc"
    Environment = "tf_lab"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}
#Deploy the private subnet
resource "aws_subnet" "mgmt_private_subnet" {
  vpc_id                  = aws_vpc.mgmt_vpc.id
  cidr_block              = aws_vpc.mgmt_vpc.cidr_block
  map_public_ip_on_launch = true
  tags = {
    Name      = "mgmt_private_sn"
    Terraform = "true"
  }
}
#Create route table
resource "aws_route_table" "mgmt_public_route_table" {
  vpc_id = aws_vpc.mgmt_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mgmt_internet_gateway.id
  }
  route {
    cidr_block         = "10.0.1.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.2.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.3.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  tags = {
    Name      = "mgmt_public_rtb"
    Terraform = "true"
  }
}
#Create route table association
resource "aws_route_table_association" "mgmt_public" {
  depends_on     = [aws_subnet.mgmt_private_subnet]
  route_table_id = aws_route_table.mgmt_public_route_table.id
  subnet_id      = aws_subnet.mgmt_private_subnet.id
}
#Create IGW
resource "aws_internet_gateway" "mgmt_internet_gateway" {
  vpc_id = aws_vpc.mgmt_vpc.id
  tags = {
    Name      = "mgmt_igw"
    Terraform = "true"
  }
}
#Create the TGW attchment
resource "aws_ec2_transit_gateway_vpc_attachment" "mgmt_tgw_attach" {
  subnet_ids         = [aws_subnet.mgmt_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  vpc_id             = aws_vpc.mgmt_vpc.id
}
#Creating the route to MGMT VPC in TGW
resource "aws_ec2_transit_gateway_route" "to_mgmt" {
  destination_cidr_block         = "10.0.0.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.mgmt_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
# Security Groups
resource "aws_security_group" "mgmt_sg" {
  name   = "mgmt-secuirty-group"
  vpc_id = aws_vpc.mgmt_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Bastion host in mgmgt vpc
resource "aws_instance" "mgmt_jump" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.mgmt_private_subnet.id
  security_groups             = [aws_security_group.mgmt_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }
  provisioner "local-exec" {
    command = "chmod 400 ${local_file.private_key_pem.filename}"
  }
  tags = {
    Name      = "Bastion Host"
    Terraform = "true"
  }
  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }
}





#Define the Prod VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.1.0/24"
  tags = {
    Name        = "prod_vpc"
    Environment = "tf_lab"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}
#Deploy the private subnet
resource "aws_subnet" "prod_private_subnet" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = aws_vpc.prod_vpc.cidr_block
  tags = {
    Name      = "prod_private_sn"
    Terraform = "true"
  }
}
#Create route table
resource "aws_route_table" "prod_private_route_table" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.0.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.2.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.3.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  tags = {
    Name      = "prod_private_rtb"
    Terraform = "true"
  }
}
#Create route table association
resource "aws_route_table_association" "prod_private" {
  depends_on     = [aws_subnet.prod_private_subnet]
  route_table_id = aws_route_table.prod_private_route_table.id
  subnet_id      = aws_subnet.prod_private_subnet.id
}
#Create the TGW attchment
resource "aws_ec2_transit_gateway_vpc_attachment" "prod_tgw_attach" {
  subnet_ids         = [aws_subnet.prod_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  vpc_id             = aws_vpc.prod_vpc.id
}
#Creating the route to Prod VPC in TGW
resource "aws_ec2_transit_gateway_route" "to_prod" {
  destination_cidr_block         = "10.0.1.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
# Create Security Group
resource "aws_security_group" "prod_sg" {
  name   = "prod-secuirty-group"
  vpc_id = aws_vpc.prod_vpc.id
  ingress {
    cidr_blocks = [
      "10.0.0.0/24"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Host in Prod VPC
resource "aws_instance" "prod_host" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.prod_private_subnet.id
  key_name        = aws_key_pair.generated.key_name
  security_groups = [aws_security_group.prod_sg.id]
  tags = {
    Name      = "Prod Host"
    Terraform = "true"
  }
}




#Define the Shared VPC
resource "aws_vpc" "shared_vpc" {
  cidr_block = "10.0.2.0/24"
  tags = {
    Name        = "shared_vpc"
    Environment = "tf_lab"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}
#Deploy the private subnet
resource "aws_subnet" "shared_private_subnet" {
  vpc_id     = aws_vpc.shared_vpc.id
  cidr_block = aws_vpc.shared_vpc.cidr_block
  tags = {
    Name      = "shared_private_sn"
    Terraform = "true"
  }
}
#Create route table
resource "aws_route_table" "shared_private_route_table" {
  vpc_id = aws_vpc.shared_vpc.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.1.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.0.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.3.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  tags = {
    Name      = "shared_private_rtb"
    Terraform = "true"
  }
}
#Create route table association
resource "aws_route_table_association" "shared_private" {
  depends_on     = [aws_subnet.shared_private_subnet]
  route_table_id = aws_route_table.shared_private_route_table.id
  subnet_id      = aws_subnet.shared_private_subnet.id
}
#Create the TGW attchment
resource "aws_ec2_transit_gateway_vpc_attachment" "shared_tgw_attach" {
  subnet_ids         = [aws_subnet.shared_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  vpc_id             = aws_vpc.shared_vpc.id
}
#Creating the route to Shared VPC in TGW
resource "aws_ec2_transit_gateway_route" "to_shared" {
  destination_cidr_block         = "10.0.2.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
# Create Security Group
resource "aws_security_group" "shared_sg" {
  name   = "shared-secuirty-group"
  vpc_id = aws_vpc.shared_vpc.id
  ingress {
    cidr_blocks = [
      "10.0.0.0/24"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Host in Shared VPC
resource "aws_instance" "shared_host" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.shared_private_subnet.id
  key_name        = aws_key_pair.generated.key_name
  security_groups = [aws_security_group.shared_sg.id]
  tags = {
    Name      = "Shared Host"
    Terraform = "true"
  }
}




#Define the Dev VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.3.0/24"
  tags = {
    Name        = "dev_vpc"
    Environment = "tf_lab"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}
#Deploy the private subnet
resource "aws_subnet" "dev_private_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = aws_vpc.dev_vpc.cidr_block
  tags = {
    Name      = "dev_private_sn"
    Terraform = "true"
  }
}
#Create route table
resource "aws_route_table" "dev_private_route_table" {
  vpc_id = aws_vpc.dev_vpc.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.1.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.2.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.0.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  tags = {
    Name      = "dev_private_rtb"
    Terraform = "true"
  }
}
#Create route table association
resource "aws_route_table_association" "dev_private" {
  depends_on     = [aws_subnet.dev_private_subnet]
  route_table_id = aws_route_table.dev_private_route_table.id
  subnet_id      = aws_subnet.dev_private_subnet.id
}
#Create the TGW attchment
resource "aws_ec2_transit_gateway_vpc_attachment" "dev_tgw_attach" {
  subnet_ids         = [aws_subnet.dev_private_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  vpc_id             = aws_vpc.dev_vpc.id
}
#Creating the route to Dev VPC in TGW
resource "aws_ec2_transit_gateway_route" "to_dev" {
  destination_cidr_block         = "10.0.3.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
# Create Security Group
resource "aws_security_group" "dev_sg" {
  name   = "dev-security-group"
  vpc_id = aws_vpc.dev_vpc.id
  ingress {
    cidr_blocks = [
      "10.0.0.0/24"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Host in Dev VPC
resource "aws_instance" "dev_host" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.dev_private_subnet.id
  key_name        = aws_key_pair.generated.key_name
  security_groups = [aws_security_group.dev_sg.id]
  tags = {
    Name      = "Dev Host"
    Terraform = "true"
  }
}





#Define the Transit VPC
resource "aws_vpc" "transit_vpc" {
  cidr_block = "10.0.4.0/23"
  tags = {
    Name        = "transit_vpc"
    Environment = "tf_lab"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}
#Deploy transit mgmt subnet
resource "aws_subnet" "transit_mgmt_subnet" {
  vpc_id                  = aws_vpc.transit_vpc.id
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.4.0/25"
  map_public_ip_on_launch = true
  tags = {
    Name      = "transit_mgmt_sn"
    Terraform = "true"
  }
}
#Create mgmt route table
resource "aws_route_table" "transit_mgmt_route_table" {
  vpc_id = aws_vpc.transit_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.transit_internet_gateway.id
  }
  tags = {
    Name      = "transit_mgmt_rtb"
    Terraform = "true"
  }
}
#Create mgmt route table association
resource "aws_route_table_association" "transit_mgmt" {
  depends_on     = [aws_subnet.transit_mgmt_subnet]
  route_table_id = aws_route_table.transit_mgmt_route_table.id
  subnet_id      = aws_subnet.transit_mgmt_subnet.id
}
# Create Security Group for mgmt subnet
resource "aws_security_group" "transit_mgmt_sg" {
  name   = "transit_mgmt-security-group"
  vpc_id = aws_vpc.transit_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Deploy transit outside subnet
resource "aws_subnet" "transit_outside_subnet" {
  vpc_id                  = aws_vpc.transit_vpc.id
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.4.128/25"
  map_public_ip_on_launch = true
  tags = {
    Name      = "transit_outside_sn"
    Terraform = "true"
  }
}
#Create outside route table
resource "aws_route_table" "transit_outside_route_table" {
  vpc_id = aws_vpc.transit_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.transit_internet_gateway.id
  }
  tags = {
    Name      = "transit_outside_rtb"
    Terraform = "true"
  }
}
#Create outside route table association
resource "aws_route_table_association" "transit_outside" {
  depends_on     = [aws_subnet.transit_outside_subnet]
  route_table_id = aws_route_table.transit_outside_route_table.id
  subnet_id      = aws_subnet.transit_outside_subnet.id
}
# Create Security Group for outside subnet
resource "aws_security_group" "transit_outside_sg" {
  name   = "transit_outside-security-group"
  vpc_id = aws_vpc.transit_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Deploy transit inside subnet
resource "aws_subnet" "transit_inside_subnet" {
  vpc_id            = aws_vpc.transit_vpc.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.5.0/24"
  tags = {
    Name      = "transit_inside_sn"
    Terraform = "true"
  }
}
#Create transit inside route table
resource "aws_route_table" "transit_inside_route_table" {
  vpc_id = aws_vpc.transit_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.asav_inside_interface.id
  }
  route {
    cidr_block         = "10.0.1.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.2.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.3.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  route {
    cidr_block         = "10.0.0.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  }
  tags = {
    Name      = "transit_inside_rtb"
    Terraform = "true"
  }
}
#Create inside route table association
resource "aws_route_table_association" "transit_inside" {
  depends_on     = [aws_subnet.transit_inside_subnet]
  route_table_id = aws_route_table.transit_inside_route_table.id
  subnet_id      = aws_subnet.transit_inside_subnet.id
}
# Create Security Group
resource "aws_security_group" "transit_inside_sg" {
  name   = "transit_inside-security-group"
  vpc_id = aws_vpc.transit_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Host in transit VPC
resource "aws_instance" "transit_host" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.transit_inside_subnet.id
  key_name        = aws_key_pair.generated.key_name
  security_groups = [aws_security_group.transit_inside_sg.id]
  tags = {
    Name      = "Transit Host"
    Terraform = "true"
  }
}
#Create IGW
resource "aws_internet_gateway" "transit_internet_gateway" {
  vpc_id = aws_vpc.transit_vpc.id
  tags = {
    Name      = "transit_igw"
    Terraform = "true"
  }
}
#Create the TGW attchment in the transit vpc
resource "aws_ec2_transit_gateway_vpc_attachment" "transit_tgw_attach" {
  subnet_ids         = [aws_subnet.transit_inside_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf_lab_tgw.id
  vpc_id             = aws_vpc.transit_vpc.id
}
#Creating the route for private subnet of Transit VPC in TGW
resource "aws_ec2_transit_gateway_route" "to_transit_inside" {
  destination_cidr_block         = "10.0.5.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.transit_tgw_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tf_lab_tgw.association_default_route_table_id
}
#Creating the mgmt interface
resource "aws_network_interface" "asav_mgmt_interface" {
  subnet_id         = aws_subnet.transit_mgmt_subnet.id
  source_dest_check = false

  security_groups = [aws_security_group.transit_mgmt_sg.id]

  tags = {
    Name = "asav_mgmt_interface"
  }
}
#Create mgmt EIP
resource "aws_eip" "asav_mgmt_eip" {
  depends_on        = [aws_internet_gateway.transit_internet_gateway]
  network_interface = aws_network_interface.asav_mgmt_interface.id
}
#Creating the public interface
resource "aws_network_interface" "asav_outside_interface" {
  subnet_id         = aws_subnet.transit_outside_subnet.id
  source_dest_check = false

  security_groups = [aws_security_group.transit_outside_sg.id]

  tags = {
    Name = "asav_outside_interface"
  }
}
#Create mgmt EIP
resource "aws_eip" "asav_outside_eip" {
  depends_on        = [aws_internet_gateway.transit_internet_gateway]
  network_interface = aws_network_interface.asav_outside_interface.id
}
#Creating the private interface
resource "aws_network_interface" "asav_inside_interface" {
  subnet_id         = aws_subnet.transit_inside_subnet.id
  source_dest_check = false

  security_groups = [aws_security_group.transit_inside_sg.id]

  tags = {
    Name = "asav_inside_interface"
  }
}

# Build the ASAv
resource "aws_instance" "cisco_asav" {
  # This AMI is only valid in us-east-1 region, with this specific instance type
  ami           = "ami-0ba630a53c34218bf"
  instance_type = "c5.xlarge"
  key_name      = aws_key_pair.generated.key_name

  network_interface {
    network_interface_id = aws_network_interface.asav_mgmt_interface.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.asav_outside_interface.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.asav_inside_interface.id
    device_index         = 2
  }
  user_data = file("aws_cisco_asav_config.txt")
  tags = {
    Name = "cisco_asav"
  }
}
