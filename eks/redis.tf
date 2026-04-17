### ElastiCache Redis

## ElastiCache subnet
resource "aws_elasticache_subnet_group" "redis_subnet" {
  name       = "${var.res_prefix}-redis-subnet-gp"
  subnet_ids = local.private_subnet_ids
}

## ElastiCache Replication Group
resource "aws_elasticache_replication_group" "redis_repgroup" {
  automatic_failover_enabled  = false
  preferred_cache_cluster_azs = var.availability_zones
  replication_group_id        = "${var.res_prefix}-redis-repgroup"
  description                 = "Redis Replication Group"
  node_type                   = "cache.t3.medium"
  num_cache_clusters          = length(var.availability_zones)
  engine                      = "redis"
  engine_version              = "7.1"
  parameter_group_name        = "default.redis7"
  port                        = 6380
  auth_token                  = var.redis_password
  transit_encryption_enabled  = true
  subnet_group_name           = aws_elasticache_subnet_group.redis_subnet.name
  security_group_ids          = [aws_security_group.sg_internal.id]
}
