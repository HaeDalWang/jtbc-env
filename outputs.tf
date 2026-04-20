output "bastion_public_ip" {
  description = "바스티온 퍼블릭 IP (SSH 또는 점프용)"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "바스티온 인스턴스 ID"
  value       = aws_instance.bastion.id
}
