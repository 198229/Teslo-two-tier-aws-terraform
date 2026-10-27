# ===========================================
# SECRETOS en SSM Parameter Store (SecureString)
# Reemplazan el texto plano en el user_data del Launch Template.
# ===========================================

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.project_name}/jwt_secret"
  type  = "SecureString"
  value = var.jwt_secret

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }
}

# Permiso minimo: la instancia solo puede leer estos dos parametros.
# (Con la clave por defecto aws/ssm no hace falta permiso kms explicito.)
resource "aws_iam_role_policy" "read_secrets" {
  name = "${var.project_name}-read-secrets"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = [
        aws_ssm_parameter.db_password.arn,
        aws_ssm_parameter.jwt_secret.arn
      ]
    }]
  })
}
