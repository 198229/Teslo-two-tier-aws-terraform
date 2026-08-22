output "alb_dns_name" {
  description = "DNS público del Load Balancer — entrá acá desde el navegador para ver la app corriendo"
  value       = aws_lb.main.dns_name
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 (útil para conectarte vía Session Manager)"
  value       = aws_instance.web.id
}

output "ec2_private_ip" {
  description = "IP privada de la instancia EC2 (no accesible desde internet, solo dentro de la VPC)"
  value       = aws_instance.web.private_ip
}

output "rds_endpoint" {
  description = "Endpoint de conexión a la base de datos RDS"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Puerto de conexión a la base de datos RDS"
  value       = aws_db_instance.main.port
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}
