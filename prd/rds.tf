# MariaDB 11.8.6 — PRD (Multi-AZ)

# --- 보안 그룹 ---
resource "aws_security_group" "rds" {
  name        = local.name_sg_rds
  description = "RDS MariaDB: allow WAS and Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MariaDB from WAS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_app.id]
  }

  ingress {
    description     = "MariaDB from Bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = local.name_sg_rds
  }
}

# --- 파라미터 그룹 (참고2.txt 기준) ---
resource "aws_db_parameter_group" "mariadb" {
  name        = "${local.name_base}-rds-param"
  family      = "mariadb11.8"
  description = "MariaDB 11.8 parameter group for ${local.name_base}"

  parameter {
    name  = "max_connections"
    value = "500"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name = "${local.name_base}-rds-param"
  }
}

# --- RDS 인스턴스 ---
resource "aws_db_instance" "main" {
  identifier = "${local.name_base}-rds"

  engine         = "mariadb"
  engine_version = "11.8.6"
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_storage_gb
  max_allocated_storage = var.rds_max_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password
  port     = 3306

  parameter_group_name = aws_db_parameter_group.mariadb.name
  db_subnet_group_name = module.vpc.database_subnet_group_name

  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.rds_multi_az
  publicly_accessible = false

  backup_retention_period = 14
  backup_window           = "18:00-19:00"         # 03:00-04:00 KST
  maintenance_window      = "sun:20:00-sun:21:00" # Sun 05:00-06:00 KST

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  performance_insights_enabled = true

  auto_minor_version_upgrade = false

  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_base}-rds-final-snapshot"
  deletion_protection       = true

  tags = {
    Name = "${local.name_base}-rds"
  }
}

# --- Enhanced Monitoring IAM Role ---
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_base}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${local.name_base}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
