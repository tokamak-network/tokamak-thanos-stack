# PRD: Preset-Based Helm Chart Deployment

```
Status: In Progress
Date: 2026-04-15
Owner: trh-platform team
Relates-to:
  - docs/design/preset-helm-values-matrix.md (ADR ① — values layering decision)
  - trh-sdk/pkg/stacks/thanos/deploy_chain.go (helm 2-pass caller)
  - trh-backend/docs/design/preset-deploy-prd.md (PRD 3 — backend orchestrator)
```

---

## Background

TRH Platform 사용자가 Preset(General/DeFi/Gaming/Full) 하나를 선택하면, 해당 Preset에
속한 모든 인프라와 서비스가 **자동으로** AWS EKS에 배포되어야 한다. 이를 위해
tokamak-thanos-stack 레포에는 두 가지 prerequisite이 필요하다:

1. **DRB VRF / AA Paymaster Helm chart 신규 추가** — Gaming/Full preset에서 필요하지만
   현재 해당 chart 자체가 존재하지 않는다.

2. **`values-{preset}.yaml` 레이어링 파일** — ADR ①에서 설계한 파일 구조가 아직 작성되지
   않아, trh-sdk가 preset 단위 helm 2-pass install을 수행할 수 없다.

3. **`generate-thanos-stack-values.sh` 하드코딩 제거** — `stack_preset`이 `defi`로
   하드코딩되어 있어 Terraform `var.preset` 값이 실제로 반영되지 않는다.

---

## Scope

### In scope
- `charts/drb-vrf/` — DRB VRF 오퍼레이터 노드 Helm chart 신규
- `charts/aa-paymaster/` — AA Paymaster Helm chart 신규
- `charts/thanos-stack/values-{base,general,defi,gaming,full}.yaml` — 레이어링 파일 5개
- `terraform/thanos-stack/scripts/generate-thanos-stack-values.sh` — `stack_preset` 하드코딩 제거

### Out of scope
- Staking V2 chart — TRH 생태계 integration 아님
- Backup & Recovery chart — AWS Backup 서비스 사용, 별도 chart 불필요
- 기존 `charts/{blockscout-stack,op-bridge,monitoring,cross-trade,uptime-service}` 수정

---

## Deliverables

### 신규 파일

#### `charts/drb-vrf/`

DRB 오퍼레이터 노드(Go, libp2p)를 Kubernetes에 배포하는 chart.

**최소 필수 values:**
```yaml
drb_vrf:
  image:
    repository: tokamaknetwork/drb-node
    tag: "sha-8c37f63"
  env:
    l2_rpc_url: ""          # trh-sdk가 --set으로 주입
    contract_address: "0x4200000000000000000000000000000000000060"
    operator_private_key: ""  # trh-sdk가 --set으로 주입
  replicaCount: 1
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
```

trh-sdk의 `InstallDRB`는 `--set` 3개(`l2_rpc_url`, `operator_private_key`, `image.tag`)만
override한다. 나머지는 chart 기본값 사용.

#### `charts/aa-paymaster/`

ERC-4337 AA Paymaster를 Kubernetes에 배포하는 chart.

**최소 필수 values:**
```yaml
aaPaymaster:
  image:
    repository: tokamaknetwork/aa-paymaster
    tag: "latest"
  env:
    l2_rpc_url: ""
    paymaster_private_key: ""
  replicaCount: 1
```

#### `charts/thanos-stack/values-base.yaml`

현재 `values.yaml`의 공통 기본값(이미지 태그, 리소스 limits, 공통 labels)을 분리.
모든 preset에서 공통으로 적용되는 값만 포함.

#### `charts/thanos-stack/values-{general,defi,gaming,full}.yaml`

ADR ① 표 기준 enable/disable 플래그:

| 모듈          | general | defi | gaming | full |
|--------------|:-------:|:----:|:------:|:----:|
| bridge        | ✅ | ✅ | ✅ | ✅ |
| blockExplorer | ✅ | ✅ | ✅ | ✅ |
| monitoring    | ❌ | ✅ | ✅ | ✅ |
| uptime        | ❌ | ✅ | ✅ | ✅ |
| crossTrade    | ❌ | ✅ | ❌ | ✅ |
| drb           | ❌ | ❌ | ✅ | ✅ |
| aaPaymaster   | ❌ | ❌ | ✅ | ✅ |
| backup        | ❌ | ❌ | ❌ | ✅ |

예시 — `values-gaming.yaml`:
```yaml
bridge:
  enabled: true
blockExplorer:
  enabled: true
monitoring:
  enabled: true
uptime:
  enabled: true
crossTrade:
  enabled: false
drb:
  enabled: true
aaPaymaster:
  enabled: true
backup:
  enabled: false
```

### 수정 파일

#### `terraform/thanos-stack/scripts/generate-thanos-stack-values.sh`

**변경 전 (L39):**
```bash
stack_preset="${TF_VAR_stack_preset:-defi}"
```

**변경 후:**
```bash
# stack_preset은 필수 환경변수 — Terraform module에서 주입
: "${TF_VAR_stack_preset:?Error: TF_VAR_stack_preset is required (general|defi|gaming|full)}"
stack_preset="$TF_VAR_stack_preset"
```

`reqenv` 섹션(L23–36)에 `TF_VAR_stack_preset` 항목 추가.

---

## trh-sdk 호출 인터페이스 (참조용)

trh-sdk `deploy_chain.go`의 helm 2-pass 호출은 이 chart 구조를 기반으로 다음과 같이
변경된다 (trh-sdk PRD 2에서 구현):

```bash
# Pass 1 — VPC/PVC only
helm upgrade --install {release} charts/thanos-stack \
  --values charts/thanos-stack/values-base.yaml \
  --values charts/thanos-stack/values-{preset}.yaml \
  --values thanos-stack-values.yaml \
  --set enable_vpc=true

# Pass 2 — full deploy
helm upgrade --install {release} charts/thanos-stack \
  --values charts/thanos-stack/values-base.yaml \
  --values charts/thanos-stack/values-{preset}.yaml \
  --values thanos-stack-values.yaml \
  --set enable_deployment=true
```

마지막 `--values thanos-stack-values.yaml`이 Terraform 렌더 동적 값(VPC ID, EFS handle 등)을
가지므로 항상 마지막 순서를 유지.

---

## Verification

- [ ] `helm lint charts/drb-vrf/ charts/aa-paymaster/ charts/thanos-stack/` 통과
- [ ] `helm template charts/thanos-stack/ -f values-base.yaml -f values-full.yaml` 렌더 성공, 모든 module key 치환 확인
- [ ] `helm template charts/thanos-stack/ -f values-base.yaml -f values-general.yaml` — drb/aaPaymaster 섹션이 렌더에 포함되지 않음 확인
- [ ] `TF_VAR_preset=full terraform plan` in `terraform/thanos-stack/` 성공
- [ ] `TF_VAR_stack_preset` 미설정 시 `generate-thanos-stack-values.sh` 명시적 오류로 종료 확인
- [ ] trh-sdk CI integration test에서 4개 preset 전부 helm dry-run 성공

---

## Implementation Checklist

- [ ] `charts/drb-vrf/Chart.yaml`, `values.yaml`, `templates/` 작성
- [ ] `charts/aa-paymaster/Chart.yaml`, `values.yaml`, `templates/` 작성
- [ ] `charts/thanos-stack/values-base.yaml` 생성 (현재 values.yaml에서 공통 추출)
- [ ] `charts/thanos-stack/values-{general,defi,gaming,full}.yaml` 4개 생성
- [ ] `generate-thanos-stack-values.sh` L39 `stack_preset:=defi` 제거, reqenv 추가
- [ ] ADR ① `preset-helm-values-matrix.md` — Implementation checklist 잔여 항목 체크
- [ ] 구현 PR merge 후 ADR ① `Status: Shipped` 업데이트
