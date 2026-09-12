# ===========================================
# BLOQUE A: LAUNCH TEMPLATE
# (Mismo comportamiento que aws_instance.web, sin scaling todavia)
# ===========================================

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm.name
  }

  vpc_security_group_ids = [aws_security_group.web.id]

  # user_data en un Launch Template SIEMPRE va en base64
  # (a diferencia de aws_instance, que lo codifica automaticamente)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              docker pull diegoleon1982/teslo-shop:latest

              # Espera activa a que RDS acepte conexiones antes de levantar la app
              echo "Esperando a que RDS este disponible en ${aws_db_instance.main.address}:5432..."
              for i in $(seq 1 30); do
                if timeout 3 bash -c "cat < /dev/null > /dev/tcp/${aws_db_instance.main.address}/5432" 2>/dev/null; then
                  echo "RDS disponible."
                  break
                fi
                echo "Intento $i: RDS todavia no responde, esperando 10s..."
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
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ec2-web-asg"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# ===========================================
# BLOQUE B: AUTO SCALING GROUP
# (min=1, desired=1, max=2 - deliberadamente chico para probar el mecanismo)
# ===========================================

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  target_group_arns         = [aws_lb_target_group.main.arn]
  health_check_type         = "ELB" # usa el health check del ALB (/api), no solo "esta prendida la instancia"
  health_check_grace_period = 400   # tiempo generoso: yum update + docker install + hasta 5min de espera activa a RDS

  min_size         = 1
  desired_capacity = 1
  max_size         = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Se asegura de crear la RDS antes de que el ASG intente lanzar instancias
  depends_on = [aws_db_instance.main]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ec2-asg"
    propagate_at_launch = true
  }
}

# ===========================================
# BLOQUE C: SCALING POLICY (target tracking por CPU)
# ===========================================

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 50.0 # manten el CPU promedio del ASG cerca del 50%
    disable_scale_in = false
  }
}

