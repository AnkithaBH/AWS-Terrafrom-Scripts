#Create a custom VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "my_vpc"
  }
}

 #Create security group for proxy client
 resource "aws_security_group" "sg-1" {
  name        = "proxy-client-sg"
  description = "Allow SSH traffic"
  vpc_id      = aws_vpc.my_vpc.id

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "proxy-client-sg"
  }
}

#Create security group rule for proxy client
resource "aws_security_group_rule" "sg-proxy-client-rule" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg-1.id
}

#Create security group for rds
 resource "aws_security_group" "sg-2" {
  name        = "rds-sg"
  description = "Allow traffic from proxy"
  vpc_id      = aws_vpc.my_vpc.id

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
 }

#Create security group rule for rds
resource "aws_security_group_rule" "sg-rds-rule" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = aws_security_group.sg-3.id
  security_group_id = aws_security_group.sg-2.id
}

#Create security group for proxy
 resource "aws_security_group" "sg-3" {
  name        = "proxy-sg"
  description = "Allow traffic from proxy client"
  vpc_id      = aws_vpc.my_vpc.id

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "proxy-sg"
  }
 }

#Create security group rule for proxy
resource "aws_security_group_rule" "sg-proxy-rule" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = aws_security_group.sg-1.id
  security_group_id = aws_security_group.sg-3.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
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

#Create Private Subnet-1
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

#Private RT association
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-RT.id
}

#Create EC2
resource "aws_instance" "my-public-instance" {
  ami           = var.ec2_ami
  instance_type = var.instance_type
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.sg-1.id]
  iam_instance_profile ="AWS-SSM-EC2"

tags = {
  Name = "my-public-instance"
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

#Create RDS subnet group
resource "aws_db_subnet_group" "rds-subnet-grp" {
  name       = "rds-subnet-grp"
  subnet_ids = [aws_subnet.public-subnet.id, aws_subnet.private-subnet-1.id]

  tags = {
    Name = "rds-subnet-grp"
  }
}

#Create MySQL RDS
resource "aws_db_instance" "mysqldb" {
  allocated_storage    = var.rds-allocated-storage
  identifier            = var.rds-db-name
  engine               = var.rds-engine
  engine_version       = var.rds-engine-version
  instance_class       = var.rds-instance-class
  username             = var.rds-username
  password             = var.rds-password
  storage_type         = var.rds-storage-type
  vpc_security_group_ids = [aws_security_group.sg-2.id]
  db_subnet_group_name = aws_db_subnet_group.rds-subnet-grp.name
  availability_zone = var.rds-az
  publicly_accessible = var.rds-public-access
  skip_final_snapshot  = true
}

#Store RDS creds as secrets in secret manager for proxy to access RDS
resource "aws_secretsmanager_secret" "sc" {
  name = "db-cred"
}

resource "aws_secretsmanager_secret_version" "rdsversion" {
  secret_id = aws_secretsmanager_secret.sc.id
  secret_string = <<EOF
   {"username":"${var.rds-username}","password":"${var.rds-password}","database":"${var.rds-db-name}"}
EOF
}

#Create IAM role and policy for RDS proxy to access secrets

resource "aws_iam_policy" "policy" {
  name        = "proxy-policy"
  policy = jsonencode(
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds",
                "secretsmanager:ListSecrets"
            ],
            "Resource": [
                "${aws_secretsmanager_secret.sc.arn}"
            ]
        }
    ]
}
)
}

resource "aws_iam_role" "rds-proxy-role" {
  name = "rds-proxy-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "rds.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "proxy-policy-attachment" {
    role = "${aws_iam_role.rds-proxy-role.name}"
    policy_arn = "${aws_iam_policy.policy.arn}"
}

#Create RDS Proxy
resource "aws_db_proxy" "proxy" {
  name                   = "rds-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = false
  role_arn               = aws_iam_role.rds-proxy-role.arn
  vpc_security_group_ids = [aws_security_group.sg-3.id]
  vpc_subnet_ids         = [aws_subnet.public-subnet.id, aws_subnet.private-subnet-1.id]

  auth {
    auth_scheme = "SECRETS"
    description = "example"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.sc.arn
  }

  tags = {
    Name = "rds-proxy"
  }
}

resource "aws_db_proxy_default_target_group" "proxy-grp" {
  db_proxy_name = aws_db_proxy.proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = "SET x=1, y=2"
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

resource "aws_db_proxy_target" "proxy-target" {
  db_instance_identifier = aws_db_instance.mysqldb.id
  db_proxy_name          = aws_db_proxy.proxy.name
  target_group_name      = aws_db_proxy_default_target_group.proxy-grp.name
}
