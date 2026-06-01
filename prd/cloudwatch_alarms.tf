# CloudWatch 알람 — SNS(이메일) 연동
# 기존 리소스 무변경, 신규 추가만

# --- SNS 토픽 ---
resource "aws_sns_topic" "alarm" {
  name = "${local.name_base}-alarm"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = "awsys@joins.com"
}

resource "aws_sns_topic_subscription" "email_saltware" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = "svvwac98@saltware.co.kr"
}

# --- ALB: Target 4XX (1분에 10건 초과, 3분 연속) ---
resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  alarm_name          = "${local.name_base}-alb-4xx"
  alarm_description   = "ALB Target 4XX count > 10 per minute for 3 consecutive minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_4XX_Count"
  dimensions          = { LoadBalancer = local.cw_alb }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- ALB: Target 5XX (1분에 1건 이상, 3분 연속) ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_base}-alb-5xx"
  alarm_description   = "ALB Target 5XX count >= 1 per minute for 3 consecutive minutes"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = local.cw_alb }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- ALB: Unhealthy Host ---
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_host" {
  alarm_name          = "${local.name_base}-alb-unhealthy-host"
  alarm_description   = "ALB unhealthy host detected"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions = {
    TargetGroup  = local.cw_tg
    LoadBalancer = local.cw_alb
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- EC2 WAS: CPU 80% ---
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  for_each = { for i, inst in aws_instance.app : format("was%02d", i + 1) => inst.id }

  alarm_name          = "${local.name_base}-${each.key}-cpu-80"
  alarm_description   = "EC2 ${each.key} CPU utilization >= 80%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- EC2 WAS: StatusCheckFailed ---
resource "aws_cloudwatch_metric_alarm" "ec2_status" {
  for_each = { for i, inst in aws_instance.app : format("was%02d", i + 1) => inst.id }

  alarm_name          = "${local.name_base}-${each.key}-status-check"
  alarm_description   = "EC2 ${each.key} status check failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- RDS: CPU 80% ---
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_base}-rds-cpu-80"
  alarm_description   = "RDS CPU utilization >= 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- RDS: 커넥션 80% (max_connections=500 기준) ---
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name_base}-rds-connections-80"
  alarm_description   = "RDS connections >= 400 (80% of max_connections 500)"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 400
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}

# --- RDS: 여유 스토리지 20% 이하 (allocated_storage 기준) ---
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${local.name_base}-rds-storage-20pct"
  alarm_description   = "RDS free storage <= 20% of allocated storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = var.rds_storage_gb * 1073741824 * 0.2
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
}
