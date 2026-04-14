# ADR ①: Preset별 Helm Values 분기

```
Status: Draft
Date: 2026-04-14
Owner: trh-platform team
Relates-to: trh-backend/docs/design/preset-module-install-aws.md (ADR ④)
Tracked-by: trh-platform/docs/design/preset-aws-rollout.md
```

---

## Context

TRH Platform은 4개 Preset(General/DeFi/Gaming/Full)을 지원하며, 각 Preset마다 활성화해야 할 Helm chart가 다르다.

| 모듈 | General | DeFi | Gaming | Full |
|------|:-------:|:----:|:------:|:----:|
| Bridge | ✅ | ✅ | ✅ | ✅ |
| Block Explorer | ✅ | ✅ | ✅ | ✅ |
| Monitoring (Grafana) | ❌ | ✅ | ✅ | ✅ |
| Uptime (Kuma) | ❌ | ✅ | ✅ | ✅ |
| CrossTrade | ❌ | ✅ | ❌ | ✅ |
| DRB VRF | ❌ | ❌ | ✅ | ✅ |
| AA Paymaster | ❌ | ❌ | ✅ | ✅ |
| Backup & Recovery | ❌ | ❌ | ❌ | ✅ |

**현재 문제:** `terraform/thanos-stack/thanos-stack-values.yaml`은 Terraform이 렌더하는 단일 파일이며, 모든 chart를 동일하게 기동한다. DRB VRF chart와 AA Paymaster chart는 Gaming/Full에서만 필요하지만, 현재 all-or-nothing 구성이다. trh-sdk는 `deploy_chain.go:561-590`에서 preset 조건부 로직을 Go 코드로 갖고 있으나, Helm 레벨의 enable/disable이 없어 불필요한 chart가 배포되거나 필요한 chart가 빠지는 경우가 발생한다.

---

## Decision

**Preset별 values 파일(`values-{general,defi,gaming,full}.yaml`)을 분기 파일로 도입하고, 공통 base values는 `values-base.yaml`로 분리한다.**

### 파일 구조

```
charts/thanos-stack/
├── values-base.yaml          # 공통 defaults (이미지 태그, 리소스 limits 등)
├── values-general.yaml       # Bridge + Explorer만 enable
├── values-defi.yaml          # + Monitoring + Uptime + CrossTrade
├── values-gaming.yaml        # + Monitoring + Uptime + DRB + AA
└── values-full.yaml          # 전부 enable
```

### values-{preset}.yaml 포맷 (예: gaming)

```yaml
# values-gaming.yaml — Gaming preset overrides
bridge:
  enabled: true
blockExplorer:
  enabled: true
monitoring:
  enabled: true
uptime:
  enabled: true
crossTrade:
  enabled: false      # Gaming에는 DeFi 모듈 없음
drb:
  enabled: true
  image:
    tag: "{{ DRB_IMAGE_TAG }}"   # trh-sdk가 terraform values 렌더 시 치환
aaPaymaster:
  enabled: true
  image:
    tag: "{{ AA_IMAGE_TAG }}"
backup:
  enabled: false
```

### trh-sdk 호출 변경

`deploy_chain.go`의 helm 2-pass 호출 시 `--values` 플래그 추가:

```bash
# Pass 2 (기존)
helm upgrade --install thanos-stack thanos-stack/thanos-stack \
  --values thanos-stack-values.yaml \
  --set enable_deployment=true

# Pass 2 (변경 후)
helm upgrade --install thanos-stack thanos-stack/thanos-stack \
  --values values-base.yaml \
  --values values-{preset}.yaml \    # preset은 trh-sdk가 DeployInput에서 주입
  --values thanos-stack-values.yaml \
  --set enable_deployment=true
```

`values-{preset}.yaml`이 base보다 나중에 적용되어 override 우선순위를 가짐. Terraform 렌더 `thanos-stack-values.yaml`은 여전히 마지막으로 적용해 VPC/EKS 동적 값을 유지.

---

## Consequences

- **Good**: Preset마다 불필요한 chart(DRB, AA Paymaster)가 배포되지 않아 리소스 절약.
- **Good**: chart enable/disable이 코드(Go)가 아닌 선언적 Helm values로 관리 → 가시성 ↑.
- **Good**: 새 Preset이나 모듈 추가 시 Go 코드 수정 없이 새 values 파일만 추가.
- **Trade-off**: `deploy_chain.go`에서 preset 조건부 Go 로직(L561-590)과 Helm values가 이중 관리될 수 있음 → 구현 시 Go 조건부 로직을 values 파일에 위임하고 제거하는 방향으로 단순화.
- **Migration**: 기존 배포된 Stack은 preset 정보가 없을 수 있음 → `general`로 간주(가장 보수적).

---

## Alternatives considered

- **단일 values.yaml + preset flag**: `--set preset=gaming` 후 template 내부에서 분기. Go template 복잡도 증가, 가독성 낮아 기각.
- **Kustomize overlay**: overlay 디렉토리 구조 추가가 필요해 helm repo 방식과 호환 불량.

---

## Implementation checklist

- [ ] `charts/thanos-stack/values-base.yaml` 생성 (현재 values.yaml에서 공통 추출)
- [ ] `charts/thanos-stack/values-{general,defi,gaming,full}.yaml` 4개 생성
- [ ] 각 preset values 파일의 enable/disable 플래그 정의 (위 표 기준)
- [ ] trh-sdk `deploy_chain.go` helm 2-pass 호출에 `--values values-{preset}.yaml` 추가
- [ ] trh-sdk `DeployInput`에 `Preset string` 필드가 전달되는지 확인 (이미 있을 경우 재사용)
- [ ] `deploy_chain.go:561-590`의 Go preset 조건부 로직 중 Helm으로 위임 가능한 부분 제거
- [ ] DRB/AA 이미지 태그 `constants.go`에서 values 파일 자동 치환 경로 확인
- [ ] Local Docker 배포 경로에 영향 없음 확인 (이 ADR은 AWS Helm 경로만)
- [ ] `Status: Accepted` 로 업데이트 (리뷰 완료 시)
- [ ] 구현 PR merge 후 `Status: Shipped` + `trh-wiki/wiki/workflows/ec2-deploy.md` gap 제거
