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
  description = "비즈니스/과제 식별용 태그(project). 리소스 이름 패턴에는 쓰이지 않음"
  type        = string
  default     = "jtbc"
}

# --- 네이밍: {environment}-{name_domain}-{name_service}-{역할} ---
variable "environment" {
  description = "환경 (예: stage, stg, prod)"
  type        = string
  default     = "dev"
}

variable "name_domain" {
  description = "도메인/업무 구역 식별자 (예: news)"
  type        = string
}

variable "name_service" {
  description = "서비스 식별자 (예: metaj)"
  type        = string
}

variable "ec2_role_name" {
  description = "EC2 역할 접미사 (예: was → …-was01, …-was02)"
  type        = string
  default     = "was"
}

variable "alb_role_name" {
  description = "ALB 리소스 역할 접미사 (예: cms → …-cms)"
  type        = string
  default     = "cms"
}

variable "bastion_role_name" {
  description = "바스티온 EC2 이름 접미사 (예: bastion → …-bastion)"
  type        = string
  default     = "bastion"
}

variable "bastion_instance_type" {
  description = "바스티온 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "바스티온 Key Pair (비우면 ec2_key_name 사용)"
  type        = string
  default     = null
}

variable "bastion_ssh_allowed_cidr_blocks" {
  description = "바스티온 SSH(22) 허용 CIDR. 비우면 인바운드 22 없음(SSM Session Manager 권장)"
  type        = list(string)
  default     = []
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
