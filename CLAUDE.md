# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

Terraform으로 JTBC AWS 계정에 VPC·ALB·WAF·EC2(WAS/바스티온)·CloudWatch 대시보드를 프로비저닝합니다.
**이 레포에 없는 것:** S3 버킷, RDS, CloudFront.

## 주요 명령어

```bash
# 초기화 (처음 또는 provider 변경 후)
terraform init

# 변경 사항 미리 보기
terraform plan

# 적용
terraform apply

# 코드 포맷
terraform fmt -recursive

# 문법 검증
terraform validate

# 특정 리소스만 적용/삭제
terraform apply -target=aws_instance.app
terraform destroy -target=aws_instance.app
```

## 시작하기

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 후
terraform init && terraform plan
```

`*.tfvars`는 `.gitignore`에 포함되어 있으므로 실제 값은 커밋하지 않습니다.

## 아키텍처

### 네이밍 규칙

`{environment}-{name_domain}-{name_service}-{역할}{01|02…}`

예: `stage-news-metaj-was01`, `stage-news-metaj-bastion01`

`local.tf`에서 모든 리소스 이름을 이 패턴으로 조합합니다. IAM/SG name_prefix는 28자 제한이 있어 `iam_prefix`로 별도 처리합니다.

### 파일별 역할

| 파일 | 내용 |
|------|------|
| `providers.tf` | AWS provider (assume_role → JTBC 계정), Terraform ≥ 1.13.0, AWS ~> 6.26.0 |
| `variables.tf` | 모든 입력 변수 정의 |
| `local.tf` | 네이밍 조합 + 태그 병합 |
| `data.tf` | 리전·AZ·Ubuntu 24.04 AMI(SSM 파라미터) 데이터 소스 |
| `network.tf` | VPC 모듈(6.5.1), 단일 NAT 게이트웨이, S3 Gateway 엔드포인트 |
| `app_alb_waf.tf` | 보안 그룹, 프라이빗 EC2(WAS), 퍼블릭 ALB, WAFv2 IP 화이트리스트 |
| `bastion.tf` | 퍼블릭 서브넷 바스티온 EC2 |
| `cloudwatch.tf` | CloudWatch 대시보드(ALB 6패널 + EC2 3패널 + CWAgent 메모리) |
| `outputs.tf` | 바스티온 퍼블릭 IP, 인스턴스 ID, 대시보드 이름 |

### 트래픽 흐름

```
Internet → WAFv2(IP 화이트리스트, default BLOCK) → ALB(퍼블릭) → EC2 WAS(프라이빗)
                                                                         ↑
                                                          Bastion(퍼블릭) → SSH
```

### 주요 설계 결정

- **WAF 기본 동작이 BLOCK** — `waf_allowed_ipv4_cidr`에 최소 1개 IP 필수. CIDR 없이 단일 IP만 입력하면 자동으로 `/32` 처리됨.
- **AMI lifecycle ignore** — EC2 인스턴스는 `ignore_changes = [ami]`로 AMI 업데이트 시 재생성 방지.
- **SSM Session Manager** — 바스티온·WAS 모두 `AmazonSSMManagedInstanceCore` 정책 부착. SSH 키 없이 접속 가능.
- **CloudWatch Agent IAM** — `CloudWatchAgentServerPolicy`는 부착되어 있으나, 에이전트 설치는 EC2 내부에서 별도 수행 필요. 메모리 메트릭(`mem_used_percent`)은 에이전트 설치 후 활성화됨.
- **EC2 user_data** — WAS 인스턴스에 nginx 자동 설치 스크립트 포함(테스트용).
