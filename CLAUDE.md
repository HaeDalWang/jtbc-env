# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

Terraform으로 JTBC AWS 계정에 VPC·ALB·WAF·EC2(WAS/바스티온)·RDS·S3·CloudFront·CloudWatch를 프로비저닝합니다.

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
├── stg/   # STG 환경 (현재 작업 중)
└── prd/   # PRD 환경 (추후 구성)
```

## 아키텍처

### 네이밍 규칙

`{environment}-{name_domain}-{name_service}-{역할}`

예: `stg-news-metaj-was-01`, `stg-news-metaj-bastion`, `stg-news-metaj-cms`

`locals.tf`에서 모든 리소스 이름을 조합합니다. **suffix(01 등) 없음** — 엑셀 구성내역서 기준.

### 파일별 역할

| 파일 | 내용 |
|------|------|
| `providers.tf` | AWS provider (assume_role → JTBC 계정), Terraform ≥ 1.13.0, AWS ~> 6.26.0 |
| `variables.tf` | 모든 입력 변수 정의 |
| `locals.tf` | 네이밍 조합 + 태그 병합 |
| `data.tf` | 리전·AZ·Ubuntu 24.04 AMI(SSM 파라미터) 데이터 소스 |
| `network.tf` | VPC 모듈(6.5.1), pub/app/db 3티어 서브넷, 단일 NAT, S3 Gateway 엔드포인트 |
| `app_alb_waf.tf` | 보안 그룹, 프라이빗 EC2(WAS), 퍼블릭 ALB, WAFv2 IP 화이트리스트 + 관리형 룰 |
| `bastion.tf` | 퍼블릭 서브넷 바스티온 EC2 |
| `rds.tf` | MariaDB 11.8.6, 파라미터 그룹(utf8mb4), Enhanced Monitoring |
| `s3.tf` | svc + adm 버킷 (Block All, SSE-S3) |
| `cloudfront.tf` | CloudFront + OAC + CloudFront Function (viewer-request IP 제어) |
| `cloudwatch.tf` | CloudWatch 대시보드 (ALB + EC2 + CWAgent + RDS) |
| `outputs.tf` | 주요 리소스 output |

### 트래픽 흐름

```
Internet → WAFv2(IP 화이트리스트 + 관리형 룰, default BLOCK) → ALB(퍼블릭) → EC2 WAS(프라이빗)
                                                                                      ↑
                                                                     Bastion(퍼블릭) → SSH

S3(svc) ← CloudFront(OAC) ← CloudFront Function(viewer-request IP 제어)
```

### 주요 설계 결정

- **WAF 기본 동작이 BLOCK** — `waf_allowed_ipv4_cidr` 필수. 단일 IP 입력 시 자동 `/32` 처리.
- **WAF 룰 3개** — IP 화이트리스트(priority 1) + AWSManagedRulesCommonRuleSet(2) + AWSManagedRulesKnownBadInputsRuleSet(3)
- **AMI lifecycle ignore** — EC2는 `ignore_changes = [ami]`로 AMI 업데이트 시 재생성 방지.
- **SSM Session Manager** — 바스티온·WAS 모두 `AmazonSSMManagedInstanceCore` 정책 부착.
- **RDS 초기 DB 미생성** — `rds_db_name = null` 기본값. 개발자가 Bastion에서 직접 생성.
- **CloudFront Function** — `/metaj/private/` 경로만 IP 제한, 나머지는 통과. WAF IP 목록과 동일하게 유지.
- **ACM/도메인 미연결** — 현재 CloudFront 기본 도메인 사용. CNAME은 아카마이 팀에 요청 필요. 추후 `aliases` + `acm_certificate_arn` 추가 시 재생성 없이 update 가능.

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

### WAS 포트
WAS 앱은 **8080** 포트. ALB 타깃 그룹, SG 인바운드, 헬스체크 모두 8080으로 통일.
nginx 기본 포트(80)와 다르므로 EC2 내부 설정 시 주의.

### CloudFront Policy ID
관리형 정책은 리전별로 ID가 다를 수 있음. 검증된 ID:
- CachingOptimized: `658327ea-f89d-4fab-a63d-7e88639e58f6`
- CORS-S3Origin (origin request): `59781a5b-3903-41f3-afcb-af62929ccde1`

### S3 태그 value 특수문자
괄호 `( )` 등 일부 특수문자 허용 안 됨. 태그 value는 영문·숫자·하이픈·언더스코어만 사용.

### IP 목록 관리
Bastion SSH, WAF, CloudFront Function 세 곳의 IP 목록은 항상 동일하게 유지.
(CloudFront Function만 WAF보다 1개 더 많을 수 있음 — 엑셀 기준 확인)
