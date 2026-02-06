# main.tf
# Simple resources to demonstrate isolated state for a staging environment

resource "aws_ssm_parameter" "app_config" {
  name        = "/${var.student_id}/staging/demo-app/config"
  description = "Application configuration for staging demo app"
  type        = "String"
  value       = "environment=staging,version=1.0.0,region=us-east-1"

  tags = {
    Name = "${var.student_id}-staging-demo-app-config"
  }
}

resource "aws_ssm_parameter" "app_feature_flags" {
  name        = "/${var.student_id}/staging/demo-app/feature-flags"
  description = "Feature flags for staging demo app"
  type        = "String"
  value       = "new-checkout=true,dark-mode=true,beta-api=false"

  tags = {
    Name = "${var.student_id}-staging-demo-app-features"
  }
}

output "config_parameter_name" {
  value = aws_ssm_parameter.app_config.name
}

output "feature_flags_parameter_name" {
  value = aws_ssm_parameter.app_feature_flags.name
}
