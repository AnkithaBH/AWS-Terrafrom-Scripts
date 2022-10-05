#Create a custom VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    Name = "my_vpc"
  }
}

#Create Public Subnet-1
resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.public_subnet_1_CIDR
  availability_zone = var.public_subnet_1_AZ

  tags = {
    Name = "public-subnet-1"
  }
}

#Create Public Subnet-2
resource "aws_subnet" "public-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.public_subnet_2_CIDR
  availability_zone = var.public_subnet_2_AZ

  tags = {
    Name = "public-subnet-2"
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
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my-ngw.id
  }

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
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-RT.id
}
resource "aws_route_table_association" "e" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-RT.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

#Create EIP
resource "aws_eip" "ngw" {
vpc      = true
}

#Create NAT Gateway
resource "aws_nat_gateway" "my-ngw" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public-subnet-1.id
  connectivity_type = "public"

  tags = {
    Name = "my-ngw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.my_igw]
}

#Create EC2
resource "aws_instance" "my-private-instance" {
  ami           = var.ec2_ami
  instance_type = var.instance_type
  associate_public_ip_address = "false"
  subnet_id = aws_subnet.private-subnet-1.id
  vpc_security_group_ids = [aws_security_group.private-sg.id]

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
  Name = "my-private-instance"
}
depends_on = [aws_nat_gateway.my-ngw]
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

#Create Security Group for EC2
resource "aws_security_group" "private-sg" {
  name ="private-sg"
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
    cidr_blocks      = ["10.0.0.0/16"]
    
  }

  egress {
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
    ipv6_cidr_blocks = ["::/0"]
  }

  tags ={
    Name = "private-sg"
  }
}

#Create Target Group
resource "aws_lb_target_group" "my-tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    interval = 30
    path = "/index.html"
    port = 80
    protocol = "HTTP"
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
    matcher = "200"
  }

  tags = {
    "Name" = "my-tg"
  }
}

#Attach EC2 to TG
resource "aws_lb_target_group_attachment" "tg-attach" {
  target_group_arn = aws_lb_target_group.my-tg.arn
  target_id        = aws_instance.my-private-instance.id
  port             = 80
}

#Security Group for ALB
resource "aws_security_group" "alb-sg" {
  name ="alb-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
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
    ipv6_cidr_blocks = ["::/0"]
  }

  tags ={
    Name = "alb-sg"
  }
}

#Create ALB
resource "aws_lb" "my-alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-subnet-1.id , aws_subnet.public-subnet-2.id]

  depends_on = [aws_instance.my-private-instance]
}

#Create ALB listener (default)
resource "aws_lb_listener" "alb-default-listener" {
  load_balancer_arn = aws_lb.my-alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-tg.arn
  }
}
