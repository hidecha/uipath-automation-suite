### RDS instance for PostgreSQL

## DB Parameter Group
resource "aws_db_parameter_group" "postgres_pg" {
  name   = "${var.res_prefix}-postgres-pg"
  family = "postgres16"
}

## DB Instance
resource "aws_db_instance" "postgres_instance" {
  identifier     = "${var.res_prefix}-postgres"
  instance_class = var.postgres_instance_type
  engine         = "postgres"
  engine_version = var.postgres_engine_version
  multi_az       = false
  username       = var.postgres_username
  password       = var.postgres_password
  db_name        = var.postgres_db_name

  # storage
  storage_type          = "gp3"
  allocated_storage     = var.postgres_storage_size
  max_allocated_storage = var.postgres_max_storage
  storage_encrypted     = true

  # network
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.sg_internal.id]
  port                   = var.postgres_port

  # backup snapshot
  backup_retention_period  = 7
  copy_tags_to_snapshot    = true
  delete_automated_backups = true
  deletion_protection      = false
  skip_final_snapshot      = true

  # window time
  backup_window      = "01:00-01:30"
  maintenance_window = "Mon:02:00-Mon:03:00"

  # options
  parameter_group_name       = aws_db_parameter_group.postgres_pg.name
  auto_minor_version_upgrade = false
}
