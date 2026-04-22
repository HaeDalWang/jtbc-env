# CloudWatch 운영 대시보드 (ALB + EC2 + CWAgent)

locals {
  cw_region = data.aws_region.current.id
  cw_alb    = aws_lb.app.arn_suffix
  cw_tg     = aws_lb_target_group.app.arn_suffix

  cw_metrics_alb_request = [
    ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.cw_alb, { stat = "Sum", period = 300 }],
    ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", local.cw_alb, { stat = "Sum", period = 300, label = "ActiveConnections" }],
  ]

  cw_metrics_alb_latency = [
    ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.cw_alb, { stat = "p50", period = 300, label = "p50", color = "#2ca02c" }],
    ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.cw_alb, { stat = "p99", period = 300, label = "p99", color = "#d62728" }],
  ]

  cw_metrics_alb_5xx = [
    ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.cw_alb, { stat = "Sum", period = 300, label = "Target 5XX", color = "#d62728" }],
    ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.cw_alb, { stat = "Sum", period = 300, label = "ELB 5XX", color = "#ff7f0e" }],
  ]

  cw_metrics_alb_health = [
    ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", local.cw_tg, "LoadBalancer", local.cw_alb, { stat = "Average", period = 60, label = "Healthy", color = "#2ca02c" }],
    ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", local.cw_tg, "LoadBalancer", local.cw_alb, { stat = "Average", period = 60, label = "Unhealthy", color = "#d62728" }],
  ]

  cw_metrics_ec2_cpu = concat(
    [for i, inst in aws_instance.app : [
      "AWS/EC2", "CPUUtilization", "InstanceId", inst.id,
      { stat = "Average", period = 60, label = format("%s%02d", var.ec2_role_name, i + 1) }
    ]],
    [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.bastion.id, {
      stat = "Average", period = 60, label = "${var.bastion_role_name}"
    }]]
  )

  cw_metrics_ec2_net = concat(
    [for i, inst in aws_instance.app : [
      "AWS/EC2", "NetworkIn", "InstanceId", inst.id,
      { stat = "Average", period = 60, label = format("In %s%02d", var.ec2_role_name, i + 1) },
    ]],
    [for i, inst in aws_instance.app : [
      "AWS/EC2", "NetworkOut", "InstanceId", inst.id,
      { stat = "Average", period = 60, label = format("Out %s%02d", var.ec2_role_name, i + 1) },
    ]],
    [
      ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.bastion.id, { stat = "Average", period = 60, label = "In ${var.bastion_role_name}" }],
      ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.bastion.id, { stat = "Average", period = 60, label = "Out ${var.bastion_role_name}" }],
    ],
  )

  cw_metrics_ec2_status = concat(
    [for i, inst in aws_instance.app : [
      "AWS/EC2", "StatusCheckFailed", "InstanceId", inst.id,
      { stat = "Maximum", period = 60, label = format("%s%02d", var.ec2_role_name, i + 1), color = i % 2 == 0 ? "#d62728" : "#ff7f0e" }
    ]],
    [["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.bastion.id, {
      stat = "Maximum", period = 60, label = "${var.bastion_role_name}", color = "#9467bd"
    }]]
  )

  cw_metrics_cwagent_mem = concat(
    [for i, inst in aws_instance.app : [
      "CWAgent", "mem_used_percent", "InstanceId", inst.id,
      { stat = "Average", period = 60, label = format("%s%02d", var.ec2_role_name, i + 1) }
    ]],
    [["CWAgent", "mem_used_percent", "InstanceId", aws_instance.bastion.id, {
      stat = "Average", period = 60, label = "${var.bastion_role_name}"
    }]]
  )

  cw_metrics_rds = [
    ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier, { stat = "Average", period = 60, label = "CPU %" }],
    ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier, { stat = "Average", period = 60, label = "Connections" }],
    ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier, { stat = "Average", period = 300, label = "Free Storage (bytes)" }],
  ]
}

resource "aws_cloudwatch_dashboard" "ops" {
  dashboard_name = substr("${local.name_base}-ops", 0, 255)

  dashboard_body = jsonencode({
    widgets = [
      # ALB 섹션
      { type = "text", x = 0, y = 0, width = 24, height = 1, properties = { markdown = "## ALB (Application Load Balancer)" } },
      { type = "metric", x = 0, y = 1, width = 6, height = 6, properties = { title = "ALB - RequestCount / ActiveConnections", metrics = local.cw_metrics_alb_request, view = "timeSeries", stacked = false, region = local.cw_region } },
      { type = "metric", x = 6, y = 1, width = 6, height = 6, properties = { title = "ALB - TargetResponseTime p50 / p99", metrics = local.cw_metrics_alb_latency, view = "timeSeries", stacked = false, region = local.cw_region, yAxis = { left = { label = "seconds", min = 0 } } } },
      { type = "metric", x = 12, y = 1, width = 6, height = 6, properties = { title = "ALB - 5XX", metrics = local.cw_metrics_alb_5xx, view = "timeSeries", stacked = false, region = local.cw_region } },
      { type = "metric", x = 18, y = 1, width = 6, height = 6, properties = { title = "ALB - Healthy / Unhealthy Hosts", metrics = local.cw_metrics_alb_health, view = "timeSeries", stacked = false, region = local.cw_region } },

      # EC2 섹션
      { type = "text", x = 0, y = 7, width = 24, height = 1, properties = { markdown = "## EC2 (WAS + Bastion)" } },
      { type = "metric", x = 0, y = 8, width = 8, height = 6, properties = { title = "EC2 - CPUUtilization", metrics = local.cw_metrics_ec2_cpu, view = "timeSeries", stacked = false, region = local.cw_region, yAxis = { left = { min = 0, max = 100, label = "%" } } } },
      { type = "metric", x = 8, y = 8, width = 8, height = 6, properties = { title = "EC2 - Network In / Out", metrics = local.cw_metrics_ec2_net, view = "timeSeries", stacked = false, region = local.cw_region } },
      { type = "metric", x = 16, y = 8, width = 8, height = 6, properties = { title = "EC2 - StatusCheckFailed", metrics = local.cw_metrics_ec2_status, view = "timeSeries", stacked = false, region = local.cw_region, annotations = { horizontal = [{ value = 1, label = "FAIL", color = "#d62728" }] } } },

      # CWAgent 섹션
      { type = "text", x = 0, y = 14, width = 24, height = 1, properties = { markdown = "## CloudWatch Agent (mem_used_percent — 에이전트 설치 후 활성화)" } },
      { type = "metric", x = 0, y = 15, width = 24, height = 6, properties = { title = "CWAgent - mem_used_percent", metrics = local.cw_metrics_cwagent_mem, view = "timeSeries", stacked = false, region = local.cw_region, yAxis = { left = { min = 0, max = 100, label = "%" } } } },

      # RDS 섹션
      { type = "text", x = 0, y = 21, width = 24, height = 1, properties = { markdown = "## RDS (MariaDB)" } },
      { type = "metric", x = 0, y = 22, width = 24, height = 6, properties = { title = "RDS - CPU / Connections / Free Storage", metrics = local.cw_metrics_rds, view = "timeSeries", stacked = false, region = local.cw_region } },
    ]
  })
}
