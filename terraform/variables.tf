variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los tags de los recursos"
  type        = string
  default     = "teslo-two-tier"
}

# ===========================================
# RED
# ===========================================

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_1" {
  description = "CIDR block de la subred pública 1 (AZ 1)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  description = "CIDR block de la subred pública 2 (AZ 2)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_1" {
  description = "CIDR block de la subred privada 1 (AZ 1)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_cidr_2" {
  description = "CIDR block de la subred privada 2 (AZ 2)"
  type        = string
  default     = "10.0.12.0/24"
}

# ===========================================
# EC2
# ===========================================

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre del Key Pair de AWS para acceso SSH (opcional, se puede dejar vacío si usás Session Manager)"
  type        = string
  default     = ""
}

# ===========================================
# RDS
# ===========================================

variable "db_instance_class" {
  description = "Tipo de instancia de RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "teslodb"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Contraseña de la base de datos (definir en terraform.tfvars, nunca commitear)"
  type        = string
  sensitive   = true
}

# ===========================================
# APLICACIÓN (Teslo Shop)
# ===========================================

variable "jwt_secret" {
  description = "Secreto usado por Teslo Shop para firmar JWT (definir en terraform.tfvars, nunca commitear)"
  type        = string
  sensitive   = true
}

# ===========================================
# ALB
# ===========================================

variable "alb_name" {
  description = "Nombre del Application Load Balancer"
  type        = string
  default     = "teslo-two-tier-alb"
}
