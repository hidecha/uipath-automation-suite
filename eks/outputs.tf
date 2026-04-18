output "bastion_public_ip_address" {
  value = aws_eip.eip_vm.public_ip
}

output "client_private_ip_address" {
  value = aws_instance.vm_client.private_ip
}

output "sqlserver_hostname" {
  value = aws_db_instance.sqlserver_instance.address
}

output "postgres_hostname" {
  value = aws_db_instance.postgres_instance.address
}

output "postgres_port" {
  value = aws_db_instance.postgres_instance.port
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis_repgroup.primary_endpoint_address
}

output "private_subnet_ip_ids" {
  value = join(",", local.private_subnet_ids)
}

output "postgres_create_db_commands" {
  description = "Run these commands from the client VM to create PostgreSQL databases"
  value = [
    for db in var.postgres_db_name :
    "PGPASSWORD='<password>' psql -h ${aws_db_instance.postgres_instance.address} -p ${aws_db_instance.postgres_instance.port} -U ${var.postgres_username} -d postgres -c 'CREATE DATABASE \"${db}\";'"
  ]
}
