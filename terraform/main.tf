# ===========================================
# 1. DATASOURCE: Obtener la AMI y AZs
# ===========================================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ===========================================
# 2. VPC Y SUBNETS (2 públicas, 2 privadas)
# ===========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Subred Pública 1 (AZ 1)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_1
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-subnet-public-1"
  }
}

# Subred Pública 2 (AZ 2)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-subnet-public-2"
  }
}

# Subred Privada 1 (AZ 1)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_1
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-subnet-private-1"
  }
}

# Subred Privada 2 (AZ 2)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_2
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-subnet-private-2"
  }
}

# ===========================================
# 3. INTERNET GATEWAY Y NAT GATEWAY
# ===========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip-nat"
  }
}

# NAT Gateway (se pone en la subred pública 1, podría ser cualquiera)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# ===========================================
# 4. TABLAS DE RUTAS Y ASOCIACIONES
# ===========================================

# Tabla de ruteo pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

# Asociar la tabla pública a ambas subredes públicas
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Tabla de ruteo privada (apunta al NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

# Asociar la tabla privada a ambas subredes privadas
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ===========================================
# 5. SECURITY GROUPS (en capas: ALB -> Web -> DB)
# ===========================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Permite HTTP/HTTPS desde Internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-alb"
  }
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg-web"
  description = "Permite trafico solo desde el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP desde ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS desde ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-web"
  }
}

# SG de la RDS (DB): Solo acepta tráfico PostgreSQL desde el SG de la EC2
resource "aws_security_group" "db" {
  name        = "${var.project_name}-sg-db"
  description = "Permite PostgreSQL solo desde las EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde Web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-db"
  }
}

# ===========================================
# 6. DB SUBNET GROUP (con 2 subnets privadas)
# ===========================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ===========================================
# 7. RDS - PostgreSQL (En la subred privada)
# ===========================================
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-rds"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage  = 20
  storage_encrypted  = true
  storage_type       = "gp2"
  db_name            = var.db_name
  username           = var.db_username
  password           = var.db_password
  port               = 5432

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # Para que no se elimine en el destroy por accidente
  skip_final_snapshot = true

  # No exponer públicamente
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-rds"
  }
}

# ===========================================
# 7.5 IAM ROLE para SSM Session Manager
# (Permite conectarse a la EC2 privada sin SSH ni IP pública)
# ===========================================
resource "aws_iam_role" "ssm" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ===========================================
# 8. INSTANCIA EC2 (En la subred privada) - Teslo Shop
# ===========================================
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # Se asegura de crear la RDS antes de intentar conectar la app
  depends_on = [aws_db_instance.main]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              docker pull diegoleon1982/teslo-shop:latest

              # Espera activa a que RDS acepte conexiones antes de levantar la app
              echo "Esperando a que RDS esté disponible en ${aws_db_instance.main.address}:5432..."
              for i in $(seq 1 30); do
                if timeout 3 bash -c "cat < /dev/null > /dev/tcp/${aws_db_instance.main.address}/5432" 2>/dev/null; then
                  echo "RDS disponible."
                  break
                fi
                echo "Intento $i: RDS todavía no responde, esperando 10s..."
                sleep 10
              done

              docker run -d \
                --name teslo-shop-app \
                --restart unless-stopped \
                -p 80:3000 \
                -e STAGE="prod" \
                -e PORT="3000" \
                -e DB_HOST="${aws_db_instance.main.address}" \
                -e DB_PORT="${aws_db_instance.main.port}" \
                -e DB_NAME="${var.db_name}" \
                -e DB_USERNAME="${var.db_username}" \
                -e DB_PASSWORD="${var.db_password}" \
                -e JWT_SECRET="${var.jwt_secret}" \
                diegoleon1982/teslo-shop:latest
              EOF

  tags = {
    Name = "${var.project_name}-ec2-web"
  }
}

# ===========================================
# 9. APPLICATION LOAD BALANCER (ALB) en subred pública
# ===========================================

# Target Group (apunta al puerto 80 de las EC2)
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# El ALB en sí (Internet-facing)
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Listener en el puerto 80
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Asociar la EC2 al Target Group
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.web.id
  port              = 80
}
