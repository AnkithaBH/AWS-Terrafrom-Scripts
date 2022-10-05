#Create a custom VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    Name = "my_vpc"
  }
}

#Create Public Subnet
resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.public_subnet_CIDR
  availability_zone = var.public_subnet_AZ

  tags = {
    Name = "public-subnet"
  }
}

#Create Private Subnet-1
resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.private_subnet_1_CIDR
  availability_zone = var.private_subnet_1_AZ

  tags = {
    Name = "private-subnet-1"
  }
}

#Create Private Subnet-2
resource "aws_subnet" "private-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.private_subnet_2_CIDR
  availability_zone = var.private_subnet_2_AZ

  tags = {
    Name = "private-subnet-2"
  }
}

#Create Private Route Table
resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-RT"
  }
}

#Create Public Route Table
resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name = "public-RT"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.private-RT.id
}

#Private RT association
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-RT.id
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private-subnet-2.id
  route_table_id = aws_route_table.private-RT.id
}

#Public RT association
resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-RT.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

#Create EC2
resource "aws_instance" "my-public-instance" {
  ami           = var.ec2_ami
  instance_type = var.instance_type
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.allow.id]

 user_data = <<EOF
#!/bin/bash
sudo su
yum update -y
yum install httpd -y
cd /var/www/html
echo " Web-Server-1" > index.html
service httpd start
chkconfig httpd on 
EOF

tags = {
  Name = "my-public-instance"
}
}

#Create Security Group
resource "aws_security_group" "allow" {
  name ="allow"
  description = "Allow public traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags ={
    Name = "allow"
  }
}

#Create EBS volume
resource "aws_ebs_volume" "root-volume" {
  size = var.ebs_size
  encrypted = var.ebs_encryption
  type = var.ebs-vol-type
  availability_zone = var.ebs_AZ

  tags = {
    Name = "root-volume"
  }
}
