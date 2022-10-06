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

#KeyPair for EC2
resource "tls_private_key" "my-efs" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "my-efs" {
  key_name   = "my-efs"
  public_key = tls_private_key.my-efs.public_key_openssh
}
#Create EC2
resource "aws_instance" "my-instance" {
  ami           = var.ec2_ami
  instance_type = var.instance_type
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.ec2-sg.id]
  key_name = "my-efs"
  iam_instance_profile = "AWS-SSM-EC2"
tags = {
  Name = "my-instance"
}
}

#Create Security Group for EC2
resource "aws_security_group" "ec2-sg" {
  name ="ec2-sg"
  description = "Allow public traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port        = 2049
    to_port          = 2049
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
    Name = "ec2-sg"
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

#Create EFS
resource "aws_efs_file_system" "my-efs" {
  creation_token = "my-efs"

  tags = {
    Name = "my-efs"
  }
}

#Create Security Group for EFS
resource "aws_security_group" "efs-sg" {
  name ="efs-sg"
  description = "Allow public traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port        = 2049
    to_port          = 2049
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
    Name = "efs-sg"
  }
}
#Create EFS mount target
resource "aws_efs_mount_target" "efs-mount-1" {
  file_system_id = aws_efs_file_system.my-efs.id
  subnet_id      = aws_subnet.public-subnet.id
  security_groups = [aws_security_group.efs-sg.id]
}

resource "null_resource" "configure_nfs" {
  depends_on = [aws_efs_mount_target.efs-mount-1,aws_instance.my-instance]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.my-efs.private_key_pem
    host     = aws_instance.my-instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
        "sudo yum -y install update",
        "sudo yum -y install nfs-utils",
        "sudo mkdir ~/efs-mount-point", 
        "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_mount_target.efs-mount-1.ip_address}:/ ~/efs-mount-point",
        #"sudo echo ${aws_efs_file_system.my-efs.dns_name}:/ ~/efs-mount-point nfs4 defaults,_netdev 0 0  | sudo cat >> /etc/fstab "
    ]
  }
}

#while mounting the efs, efs domain is not getting resolved so have given the mount target ip
