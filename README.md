# jtbc-env

Terraform으로 JTBC AWS 계정에 VPC·ALB·WAF·EC2(WAS/바스티온)·RDS·S3·CloudFront·CloudWatch를 프로비저닝합니다.
STG와 PRD 두 환경을 독립 디렉토리로 관리합니다.

## 구성 요약

| 리소스 | 내용 |
|--------|------|
| 네트워크 | VPC, pub/app/db 3티어 서브넷, 단일 NAT, S3 Gateway 엔드포인트 |
| 앱 | 프라이빗 EC2(WAS), 퍼블릭 ALB(HTTPS), WAFv2 IP 화이트리스트 |
| DB | MariaDB 11.8.6 (RDS), utf8mb4 파라미터 그룹 |
| 스토리지 | S3 svc/adm 버킷 (Block All, SSE-S3) |
| CDN | CloudFront + OAC + CloudFront Function (IP 접근 제어) |
| 접속 | 퍼블릭 서브넷 Bastion (SSH 22/2211, SSM 지원) |
| 관측 | CloudWatch 대시보드 (ALB + EC2 + CWAgent + RDS) |
| 인증서 | ACM *.jtbc.co.kr 와일드카드 (CloudFront: us-east-1, ALB: ap-northeast-2) |

## 디렉토리 구조

```
jtbc-env/
├── stg/   # STG 환경
└── prd/   # PRD 환경
```

각 환경 디렉토리는 동일한 파일 구조를 가지며, `variables.tf` 기본값과 `acm.tf` 방식이 다릅니다.

## 사용

```bash
cd stg   # 또는 prd
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 (IP 목록, 키페어, RDS 패스워드 등)
export TF_VAR_rds_password="패스워드"
terraform init && terraform plan
```

`*.tfvars`는 `.gitignore`에 포함되어 있으므로 실제 값은 저장소에 올리지 않습니다.

## STG vs PRD 주요 차이점

| 항목 | STG | PRD |
|------|-----|-----|
| VPC CIDR | 10.10.2.0/24 | 10.10.1.0/24 |
| WAS | t3.medium / 1대 | t3.large / 2대 |
| RDS | db.t3.medium, Single-AZ | db.t3.large, Multi-AZ |
| RDS 백업 | 7일 | 14일, 스토리지 자동 확장(최대 200GB) |
| ACM | resource 직접 생성 | data source로 기존 인증서 참조 |
| CloudFront | stg-mj-static.jtbc.co.kr | prd-mj-static.jtbc.co.kr |
| ALB | stg-metaj-cms.jtbc.co.kr | prd-metaj-cms.jtbc.co.kr |

## 도메인 연결

도메인 관리는 아카마이(고객사). 아래 CNAME을 아카마이 팀에 요청:

| 도메인 | 값 |
|--------|-----|
| `stg-mj-static.jtbc.co.kr` | CloudFront 도메인 (`terraform output cloudfront_domain`) |
| `stg-metaj-cms.jtbc.co.kr` | ALB DNS (`terraform output alb_dns_name`) |
| `prd-mj-static.jtbc.co.kr` | CloudFront 도메인 |
| `prd-metaj-cms.jtbc.co.kr` | ALB DNS |
