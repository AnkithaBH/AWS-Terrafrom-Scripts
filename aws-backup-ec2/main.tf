#Create a custom VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    Name = "my_vpc"
  }
}

#Create Private Subnet
resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.private_subnet_1_CIDR
  availability_zone = var.private_subnet_1_AZ

  tags = {
    Name = "private-subnet-1"
  }
}

#Create Private Route Table
resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-RT"
  }
}
resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.private-RT.id
}

#Private RT association with private subnet
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-RT.id
}

#Create EC2
resource "aws_instance" "my-private-instance" {
  ami           = var.ec2_ami
  instance_type = var.instance_type
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.private-subnet-1.id
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
  Name = "my-private-instance"
}
}

#Create Security Group
resource "aws_security_group" "allow" {
  name ="allow"
  description = "Allow public traffic"
  vpc_id      = aws_vpc.my_vpc.id

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

#Create Backup Vault
resource "aws_backup_vault" "pvt-vault" {
  name        = "pvt-vault"
  #kms_key_arn = default
}

#Create Backup plan
resource "aws_backup_plan" "my-backup-plan" {
  name = "my-backup-plan"

  rule {
    rule_name         = "my-backup-rule"
    target_vault_name = aws_backup_vault.pvt-vault.name
    schedule          = "cron(15 12 29 9 ? 2022)"

    lifecycle {
    delete_after = 1
    }
    start_window = 60
    completion_window = 480
  }
  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "disabled"
    }
    resource_type = "EC2"
  }
}

#IAM role with the default managed IAM Policy for allowing AWS Backup to create backups.
resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.example.name
}

#Resource selection
resource "aws_backup_selection" "pvt-instance-sel" {
  iam_role_arn = aws_iam_role.example.arn
  name         = "pvt-instance-sel"
  plan_id      = aws_backup_plan.my-backup-plan.id

  resources = [
    aws_instance.my-private-instance.arn
  ]
}
