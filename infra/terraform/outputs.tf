output "alb_dns_name" { value = module.alb.alb_dns_name }
output "db_private_ip" { value = try(aws_instance.db[0].private_ip, null) }
output "monitoring_private_ip" { value = try(aws_instance.monitoring[0].private_ip, null) }
output "monitoring_instance_id" { value = try(aws_instance.monitoring[0].id, null) }
