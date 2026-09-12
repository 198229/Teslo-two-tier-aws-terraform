# ===========================================
# CloudFront Distribution delante del ALB
# ===========================================

resource "aws_cloudfront_distribution" "main" {
  enabled = true
  comment = "${var.project_name} - CDN delante del ALB"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # el ALB solo tiene listener 80 por ahora
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https" # CloudFront fuerza HTTPS al cliente, con su propio cert

    forwarded_values {
      query_string = true
      headers      = ["*"] # necesario para que pasen headers como Authorization (JWT) hacia el ALB

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0 # sin cache por defecto, porque es una API, no contenido estatico
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # usa el certificado *.cloudfront.net que AWS da gratis
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}
