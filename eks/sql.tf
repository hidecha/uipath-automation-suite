### RDS instance for SQL Server

## DB Subnet
resource "aws_db_subnet_group" "db_subnet" {
  name       = "${var.res_prefix}-db-subnet-gp"
  subnet_ids = [aws_subnet.subnet_private[0].id, aws_subnet.subnet_private[1].id]
}

## DB Parameter Group
resource "aws_db_parameter_group" "sqlserver_pg" {
  name   = "${var.res_prefix}-sqlserver-pg"
  family = "sqlserver-se-15.0"
}

## DB Option Group
resource "aws_db_option_group" "sqlserver_opg" {
  name                 = "${var.res_prefix}-sqlserver-opg"
  engine_name          = "sqlserver-se"
  major_engine_version = "15.00"
}

## DB Instance
resource "aws_db_instance" "sqlserver_instance" {
  identifier     = "${var.res_prefix}-database"
  instance_class = var.db_instance_type
  engine         = "sqlserver-se"
  engine_version = "15.00.4236.7.v1"
  license_model  = "license-included"
  multi_az       = false
  username       = var.sql_username
  password       = var.sql_password

  # storage
  storage_type          = "gp3"
  allocated_storage     = 256
  max_allocated_storage = 1000
  storage_encrypted     = true

  # network
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.sg_internal.id]
  port                   = 1433

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
  parameter_group_name       = aws_db_parameter_group.sqlserver_pg.name
  option_group_name          = aws_db_option_group.sqlserver_opg.name
  character_set_name         = "SQL_Latin1_General_CP1_CI_AS"
  timezone                   = "Tokyo Standard Time"
  auto_minor_version_upgrade = false
}
