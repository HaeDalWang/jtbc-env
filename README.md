# jtbc-env

Terraform으로 VPC·ALB·WAF·EC2(WAS/바스티온)·CloudWatch 대시보드 등을 구성합니다.

## 예상 아키텍처 대비 이 레포 범위

**이 버전에는 없음:** S3 버킷 2개, RDS, CloudFront(CF).  

## 구성 요약

- 네트워크: VPC, 퍼블릭/프라이빗 서브넷, NAT, S3 **Gateway** VPC 엔드포인트(버킷 리소스 아님)
- 앱: 프라이빗 EC2(WAS), 퍼블릭 ALB, WAF IP 화이트리스트
- 접속: 퍼블릭 서브넷 bastion
- 관측: CloudWatch 대시보드, EC2에 CloudWatch Agent용 IAM

## 사용

`terraform.tfvars.example`을 참고해 `terraform.tfvars`를 채운 뒤 `terraform init` → `plan` → `apply`.

`.gitignore`에 `*.tfvars`가 있으므로 실제 값은 저장소에 올리지 않는 것이 좋습니다.
