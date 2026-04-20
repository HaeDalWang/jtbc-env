variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet CIDR"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24", "10.10.4.0/24"]
}

variable "private_subnet_cidr" {
  description = "Private Subnet CIDR"
  type        = list(string)
  default     = ["10.10.5.0/24", "10.10.6.0/24", "10.10.7.0/24", "10.10.8.0/24"]
}
variable "project_name" {
  description = "프로젝트 식별자 (VPC·리소스 이름 접두어로 사용)"
  type        = string
  default     = "jtbc"
}

variable "project_prefix" {
  description = "프로젝트 식별자 (VPC·리소스 이름 접두어로 사용)"
  type        = string
  default     = "jtbc"
}

variable "environment" {
  description = "환경 구분 (dev, stg, prod 등). 리소스 이름에 포함됩니다."
  type        = string
  default     = "dev"
}

variable "tag_owner" {
  description = "리소스 owner 태그"
  type        = string
  default     = "platform"
}

variable "additional_tags" {
  description = "provider default_tags 및 로컬 tags에 병합할 추가 태그"
  type        = map(string)
  default     = {}
}

# --- ALB / EC2 / WAF ---
variable "ec2_instance_count" {
  description = "프라이빗 서브넷에 배치할 EC2 대수 (ALB 타깃)"
  type        = number
  default     = 2

  validation {
    condition     = var.ec2_instance_count >= 1 && var.ec2_instance_count <= 10
    error_message = "ec2_instance_count는 1~10 사이여야 합니다."
  }
}

variable "ec2_instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "ec2_key_name" {
  description = "EC2 Key Pair 이름 (비우면 SSM 접속만 권장)"
  type        = string
  default     = null
}

variable "alb_listener_port" {
  description = "ALB 리스너 포트 (일반적으로 80)"
  type        = number
  default     = 80
}

variable "target_port" {
  description = "EC2에서 수신할 애플리케이션 포트 (ALB 타깃 포트)"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "타깃 그룹 헬스 체크 경로"
  type        = string
  default     = "/"
}

variable "waf_allowed_ipv4_cidr" {
  description = "WAF 화이트리스트 IPv4. CIDR(예: 1.2.3.0/24) 또는 단일 IP만 적으면 자동으로 /32 처리됩니다."
  type        = list(string)

  validation {
    condition     = length(var.waf_allowed_ipv4_cidr) >= 1
    error_message = "WAF 화이트리스트에 최소 1개의 IPv4 CIDR이 필요합니다."
  }
}
