# PRD 환경 — 추후 구성 예정
# stg/ 디렉토리를 참고하여 prd 값으로 변경 후 사용

# 주요 변경 사항 (stg → prd):
#   environment         = "prd"
#   vpc_cidr            = "10.10.1.0/24"
#   public_subnet_cidr  = ["10.10.1.0/27", "10.10.1.32/27"]
#   private_subnet_cidr = ["10.10.1.64/26", "10.10.1.128/26"]
#   db_subnet_cidr      = ["10.10.1.192/27", "10.10.1.224/27"]
#   ec2_instance_type   = "t3.large"
#   ec2_instance_count  = 2
#   rds_instance_class  = "db.t3.large"
#   rds_multi_az        = true
