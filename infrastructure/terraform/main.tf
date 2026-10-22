resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "smart-inventory-vpc"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name      = "smart-inventory-public-a"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name      = "smart-inventory-public-b"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "smart-inventory-igw"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "smart-inventory-public-rt"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name      = "smart-inventory-private-a"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name      = "smart-inventory-private-b"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "smart-inventory-private-rt"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "smart-inventory-alb-sg"
  description = "Allow public HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward traffic to the API inside the VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name      = "smart-inventory-alb-sg"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "api" {
  name        = "smart-inventory-api-sg"
  description = "Allow API traffic only from the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API traffic from the load balancer"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "smart-inventory-api-sg"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "database" {
  name        = "smart-inventory-db-sg"
  description = "Allow PostgreSQL traffic only from the API"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from the API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  egress {
    description = "Allow outbound connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "smart-inventory-db-sg"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_db_subnet_group" "main" {
  name = "smart-inventory-db-subnets"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name      = "smart-inventory-db-subnets"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_db_instance" "main" {
  identifier                  = "smart-inventory-postgres"
  engine                      = "postgres"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  storage_type                = "gp3"
  db_name                     = "smart_inventory"
  username                    = "inventory_user"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false
  storage_encrypted      = true

  skip_final_snapshot = true

  tags = {
    Name      = "smart-inventory-postgres"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "api_instance" {
  name = "smart-inventory-api-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_ssm" {
  role       = aws_iam_role.api_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "api" {
  name = "smart-inventory-api-instance-profile"
  role = aws_iam_role.api_instance.name
}

resource "aws_instance" "api" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.api.id]
  iam_instance_profile        = aws_iam_instance_profile.api.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name      = "smart-inventory-api"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_lb_target_group" "api" {
  name        = "smart-inventory-api-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled  = true
    path     = "/health"
    matcher  = "200-399"
    protocol = "HTTP"
  }

  tags = {
    Name      = "smart-inventory-api-tg"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_lb" "main" {
  name               = "smart-inventory-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name      = "smart-inventory-alb"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_target_group_attachment" "api" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.api.id
  port             = 3000
}

resource "aws_iam_role_policy" "api_database_secret" {
  name = "smart-inventory-api-database-secret"
  role = aws_iam_role.api_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_db_instance.main.master_user_secret[0].secret_arn
    }]
  })
}

output "load_balancer_url" {
  value = "http://${aws_lb.main.dns_name}"
}

output "database_endpoint" {
  value = aws_db_instance.main.address
}

output "database_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name      = "github-actions-oidc"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "smart-inventory-DevOps-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:Geevfted@195492645/Smart-Inventory-DevOps@1417050993:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Name      = "smart-inventory-DevOps-github-actions-role"
    Project   = "smart-inventory"
    ManagedBy = "Terraform"
  }
}

data "aws_ecr_repository" "smart_inventory" {
  name = "smart-inventory-api"
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "smart-inventory-DevOps-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = data.aws_ecr_repository.smart_inventory.arn
      }
    ]
  })
}