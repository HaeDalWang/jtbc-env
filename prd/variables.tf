# --- 네이밍 ---
variable "environment" {
  type    = string
  default = "stg"
}

variable "name_domain" {
  type    = string
  default = "news"
}

variable "name_service" {
  type    = string
  default = "metaj"
}

variable "project_name" {
  type    = string
  default = "jtbc"
}

variable "tag_owner" {
  type    = string
  default = "platform"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}

# --- 네트워크 ---
variable "vpc_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "public_subnet_cidr" {
  type    = list(string)
  default = ["10.10.2.0/27", "10.10.2.32/27"]
}

variable "private_subnet_cidr" {
  type    = list(string)
  default = ["10.10.2.64/26", "10.10.2.128/26"]
}

variable "db_subnet_cidr" {
  type    = list(string)
  default = ["10.10.2.192/27", "10.10.2.224/27"]
}

# --- EC2 역할 이름 ---
variable "ec2_role_name" {
  type    = string
  default = "was"
}

variable "alb_role_name" {
  type    = string
  default = "cms"
}

variable "bastion_role_name" {
  type    = string
  default = "bastion"
}

# --- EC2 ---
variable "ec2_instance_count" {
  type    = number
  default = 1

  validation {
    condition     = var.ec2_instance_count >= 1 && var.ec2_instance_count <= 10
    error_message = "ec2_instance_count는 1~10 사이여야 합니다."
  }
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ec2_key_name" {
  type    = string
  default = null
}

variable "ec2_ebs_size_gb" {
  description = "WAS EC2 루트 볼륨 크기 (GiB)"
  type        = number
  default     = 30
}

# --- Bastion ---
variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "bastion_key_name" {
  type    = string
  default = null
}

variable "bastion_ssh_allowed_cidr_blocks" {
  description = "바스티온 SSH(22) 허용 CIDR. 비우면 SSM만 사용"
  type        = list(string)
  default     = []
}

variable "bastion_ebs_size_gb" {
  description = "바스티온 EC2 루트 볼륨 크기 (GiB)"
  type        = number
  default     = 10
}

# --- ALB / WAF ---
variable "alb_listener_port" {
  type    = number
  default = 80
}

variable "target_port" {
  description = "WAS 앱 포트"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "waf_allowed_ipv4_cidr" {
  description = "WAF 화이트리스트 IPv4. 단일 IP는 자동으로 /32 처리"
  type        = list(string)

  validation {
    condition     = length(var.waf_allowed_ipv4_cidr) >= 1
    error_message = "WAF 화이트리스트에 최소 1개의 IPv4 CIDR이 필요합니다."
  }
}

# --- RDS ---
variable "rds_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "rds_storage_gb" {
  type    = number
  default = 50
}

variable "rds_db_name" {
  description = "RDS 초기 DB 이름. null이면 DB 미생성 (개발자가 Bastion에서 직접 생성)"
  type        = string
  default     = null
  nullable    = true
}

variable "rds_username" {
  type    = string
  default = "jtbc"
}

variable "rds_password" {
  description = "RDS 마스터 패스워드 (tfvars 또는 환경변수로 주입)"
  type        = string
  sensitive   = true
}
