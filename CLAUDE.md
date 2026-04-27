# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

Terraform으로 JTBC AWS 계정에 VPC·ALB·WAF·EC2(WAS/bastion)·RDS·S3·CloudFront·CloudWatch를 프로비저닝합니다.
STG와 PRD 두 환경을 독립 디렉토리로 관리합니다.

## 주요 명령어

```bash
# 초기화 (처음 또는 provider 변경 후)
terraform init

# 변경 사항 미리 보기 (Claude는 plan까지만 실행, apply는 사용자가 직접)
terraform plan

# 코드 포맷
terraform fmt -recursive

# 문법 검증
terraform validate
```

## 시작하기

```bash
cd stg   # 또는 prd
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 후
terraform init && terraform plan
```

`*.tfvars`는 `.gitignore`에 포함되어 있으므로 실제 값은 커밋하지 않습니다.

## Git 규칙

- add, commit 등 모든 명령어는 사용자가 요청시에만 수행
- **Claude는 commit까지만 수행, push는 사용자가 직접 진행**
- `terraform.tfvars`는 커밋 금지 (민감 정보 포함)

## 디렉토리 구조

```
jtbc-env/
├── stg/   # STG 환경 (배포 완료)
└── prd/   # PRD 환경 (배포 완료)
```

## 아키텍처

### 네이밍 규칙

`{environment}-{name_domain}-{name_service}-{역할}`

예: `stg-news-metaj-was-01`, `stg-news-metaj-bastion`, `stg-news-metaj-cms`

`locals.tf`에서 모든 리소스 이름을 조합합니다. **suffix(01 등) 없음** — 엑셀 구성내역서 기준.

### 파일별 역할

| 파일 | 내용 |
|------|------|
| `providers.tf` | AWS provider (assume_role → JTBC 계정), Terraform ≥ 1.13.0, AWS ~> 6.26.0, us-east-1 alias provider (ACM용) |
| `variables.tf` | 모든 입력 변수 정의 |
| `locals.tf` | 네이밍 조합 + 태그 병합 |
| `data.tf` | 리전·AZ·Ubuntu 24.04 AMI·aws_caller_identity 데이터 소스 |
| `network.tf` | VPC 모듈(6.5.1), pub/app/db 3티어 서브넷, NAT, S3 Gateway 엔드포인트 |
| `app_alb_waf.tf` | SG, WAS EC2, ALB(HTTPS:443), WAFv2, WAS IAM 인라인 정책 |
| `bastion.tf` | 퍼블릭 서브넷 바스티온 EC2 |
| `rds.tf` | MariaDB 11.8.6, 파라미터 그룹(utf8mb4), Enhanced Monitoring |
| `s3.tf` | svc + adm 버킷 (Block All, SSE-S3) |
| `cloudfront.tf` | CloudFront + OAC + CloudFront Function (viewer-request IP 제어) |
| `acm.tf` | ACM 인증서 (STG: resource 생성, PRD: data source 참조) |
| `cloudwatch.tf` | CloudWatch 대시보드 (ALB + EC2 + CWAgent + RDS) |
| `outputs.tf` | 주요 리소스 output |

### 트래픽 흐름

```
Internet → WAFv2(IP 화이트리스트 + 관리형 룰, default BLOCK) → ALB(HTTPS:443) → EC2 WAS(프라이빗)
                                                                                         ↑
                                                                        Bastion(퍼블릭) → SSH 22/2211

S3(svc) ← CloudFront(OAC) ← CloudFront Function(viewer-request: /metaj/private/ IP 제어)
```

### STG vs PRD 주요 차이점

| 항목 | STG | PRD |
|------|-----|-----|
| VPC CIDR | 10.10.2.0/24 | 10.10.1.0/24 |
| WAS 타입/대수 | t3.medium / 1대 | t3.large / 2대 |
| RDS 타입 | db.t3.medium | db.t3.large |
| RDS Multi-AZ | false | true |
| RDS 백업 보존 | 7일 | 14일 |
| RDS 스토리지 자동 확장 | 없음 | 최대 200GB |
| RDS deletion_protection | false | true |
| NAT Gateway | 단일 | 단일 (비용 고려) |
| ACM | resource 생성 | data source 참조 |
| CloudFront alias | stg-mj-static.jtbc.co.kr | prd-mj-static.jtbc.co.kr |
| ALB 도메인 | stg-metaj-cms.jtbc.co.kr | prd-metaj-cms.jtbc.co.kr |

### WAS IAM 인라인 정책 (단일 정책으로 통합)

`{role}-policy` 하나에 아래 권한 통합:
- SSM Parameter Store: `/metaj-cms/*` 읽기
- S3: svc/adm 버킷 PutObject·GetObject·DeleteObject·ListBucket
- CloudFront: CreateInvalidation·GetInvalidation

## AWS 리소스 작성 시 주의사항 (실수 방지)

### 한글 사용 금지 위치
AWS API로 전달되는 필드에는 한글 사용 불가. 에러 발생 확인된 위치:
- Security Group `description`
- S3 버킷 태그 value
- RDS 관련 태그 value

`variables.tf`, `outputs.tf`의 `description`은 Terraform 내부 메타데이터라 한글 사용 가능.

### RDS 패스워드 제한
`/`, `@`, `"`, 공백 4가지 사용 불가. `terraform.tfvars`에서 해당 문자 제외.

### Security Group name vs name_prefix
`name_prefix` 사용 시 AWS가 랜덤 suffix를 붙여 엑셀 기준 이름과 불일치. **반드시 `name`으로 고정**.
단, `name`으로 고정 시 `description` 변경이 SG 재생성을 유발하므로 description은 수정하지 않는다.

### WAS 포트
WAS 앱은 **8080** 포트. ALB 타깃 그룹, SG 인바운드, 헬스체크 모두 8080으로 통일.

### CloudFront Policy ID
관리형 정책은 리전별로 ID가 다를 수 있음. 검증된 ID:
- CachingOptimized: `658327ea-f89d-4fab-a63d-7e88639e58f6`
- CORS-S3Origin (origin request): `59781a5b-3903-41f3-afcb-af62929ccde1`

### S3 태그 value 특수문자
괄호 `( )` 등 일부 특수문자 허용 안 됨. 태그 value는 영문·숫자·하이픈·언더스코어만 사용.

### IP 목록 관리
Bastion SSH, WAF, CloudFront Function 세 곳의 IP 목록은 항상 동일하게 유지.
WAF IP 목록 = Bastion SSH IP 목록 + 1개 (1.209.9.201/32 추가).

### ACM 리전
- CloudFront용 ACM은 반드시 **us-east-1** (버지니아)
- ALB용 ACM은 **ap-northeast-2** (서울)
- `providers.tf`에 `aws.us_east_1` alias provider 선언 필요

### CNAME 요청 대상
도메인 관리는 아카마이(고객사). 아래 두 CNAME을 아카마이 팀에 요청:
- `stg-mj-static.jtbc.co.kr` → CloudFront 도메인
- `stg-metaj-cms.jtbc.co.kr` → ALB DNS
