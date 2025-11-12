output "alb_dns_name" { value = module.alb.alb_dns_name }
output "db_private_ip" { value = aws_instance.db.private_ip }
output "monitoring_private_ip" { value = aws_instance.monitoring.private_ip }
output "monitoring_instance_id" { value = aws_instance.monitoring.id }
