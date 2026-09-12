output "alb_dns_name" {
  description = "DNS público del Load Balancer — entrá acá desde el navegador para ver la app corriendo"
  value       = aws_lb.main.dns_name
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group (util para ver instancias activas en la consola o CLI)"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID del Launch Template usado por el ASG"
  value       = aws_launch_template.web.id
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

output "cloudfront_domain_name" {
  description = "Dominio publico de CloudFront (usar este en vez del ALB directo)"
  value       = aws_cloudfront_distribution.main.domain_name
}
