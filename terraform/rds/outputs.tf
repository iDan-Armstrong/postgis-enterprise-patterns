output "endpoint" {
  description = "host:port for client connections"
  value       = aws_db_instance.this.endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN of the managed master password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Attach-point for additional ingress rules"
  value       = aws_security_group.db.id
}

output "instance_arn" {
  value = aws_db_instance.this.arn
}
