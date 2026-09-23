# sj-lab-k8s-manifests — 배포 매니페스트 (GitOps 소스)

> sj-lab 전 서비스의 **Helm 차트 모음**이자 ArgoCD가 바라보는 **단일 진실 공급원(Single Source of Truth)** 입니다.
> 애플리케이션 코드는 없고, "무엇이 어떤 설정으로 클러스터에 떠 있는가"가 전부 이 저장소에 있습니다.

| | |
|---|---|
| **배포 방식** | Jenkins(빌드·이미지 push) → 이 저장소의 `image.tag` 자동 커밋 → ArgoCD 동기화(selfHeal·prune) |
| **레지스트리** | `sj-lab-registry.kr.ncr.ntruss.com` (NCP Container Registry) |
| **네임스페이스** | 대부분 `sj-lab` |

---

## 1. 배포 파이프라인

```
개발자 git push (서비스 저장소)
   │
   ▼
Jenkins ── 빌드 ── 이미지 push ──▶ NCP 레지스트리
   │
   └─ 이 저장소를 clone → <서비스>/values.yaml 의 image.tag 수정 → 커밋·push
                                   │
                                   ▼
                           ArgoCD(자동 동기화)
                                   │
                                   ▼
                              Kubernetes 롤아웃
```

**`image.tag`는 Jenkins가 관리하는 값**입니다. 사람이 임의로 낮추거나 되돌리지 않습니다(다음 빌드와 충돌).

---

## 2. 차트 목록

| 차트 | 이미지 | 노출 | 비고 |
|---|---|---|---|
| `apigateway` | `sj-lab-apigateway` | NodePort 30089 → 8100 | Spring Cloud Gateway |
| `discoveryserver` | `sj-lab-discoveryserver` | NodePort 30087 → 8761 | Eureka, `replicaCount: 1` 고정 |
| `mapservice-rest` | `mapservice-rest` | ClusterIP | 지도·시설물 API |
| `sj-lab-scheduler` | `sj-lab-scheduler` | ClusterIP | 공공데이터 수집 배치 |
| `sj-lab-authserver` | `sj-lab-authserver` | ClusterIP | 로그인·JWT |
| `fast-api-ai` | `fast-api-ai` | ClusterIP 80 → 8000 | FastAPI |
| `sj-qfieldsync` | `sj-qfieldsync` | — | 동기화 워커 |
| `sj-lab-webserver` | `nginx` | NodePort 32080 | 정적 사이트(허브·지도) 서빙 |
| `postgres`, `postgres-qfield` | PostGIS | — | DB |
| `geoserver`, `jenkins`, `dashboard` | 외부 이미지 | — | 부가 도구 |
| `argocd` | — | — | ArgoCD가 자기 자신을 관리하는 `Application` 리소스 |

---

## 3. 면접에서 봐주셨으면 하는 부분

### ① 설정 외부화 원칙을 전 서비스에 동일하게

Spring 서비스는 모두 같은 패턴입니다 — `files/application-prod.yml`을 ConfigMap으로 마운트하고 `SPRING_PROFILES_ACTIVE`, `SPRING_CONFIG_LOCATION=classpath:/,file:/app/config/`로 주입합니다. 서비스 저장소는 public이므로 **환경별 값과 비밀값이 코드에 섞이지 않습니다.**

ConfigMap이 있는 차트는 `deployment.yaml`에 체크섬 애노테이션을 넣어, **설정만 바꿔도 파드가 자동 재시작**되도록 했습니다.

```yaml
annotations:
  configmap-checksum: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

### ② Secret은 "필수"와 "선택"을 구분

같은 `secretKeyRef`라도 서비스 성격에 따라 다르게 걸었습니다.

| Secret | 사용처 | 필수 여부 | 없을 때 |
|---|---|---|---|
| `auth-jwt-secret` | 로그인 서버 서명 키 | **필수** | 파드가 뜨지 않음(의도) — 공개 기본값으로 서명하지 않기 위함 |
| `qfield-credentials` | 첨부 파일 중계 계정 | 선택(`optional: true`) | 파드 정상, **중계 API만 503** |
| `auth-demo-credentials` | 체험 계정 | 선택 | 파드 정상, **데모 버튼만 503** |
| `ncp-registry-secret` | 이미지 pull | 필수 | `ImagePullBackOff` |

"조용히 잘못된 상태로 뜨는 것"과 "부가 기능만 죽는 것"을 구분해, 사고가 배포 시점에 드러나게 했습니다. 이름·용도·확인 명령은 총괄 저장소의 `docs/k8s-secrets.md`에 정리했습니다(값은 기록하지 않음).

### ③ 차트 수정 시 검증 루틴

```bash
helm lint <chart>
helm template <chart> -f <chart>/values.yaml
helm template <chart> | kubectl apply --dry-run=server -f -
```

Jenkins 자동 커밋이 계속 쌓이므로 **수정 전 `git pull`** 은 필수입니다. 이 저장소에는 편집 후 자동으로 `helm lint`를 돌리는 훅도 넣어 두었습니다.

---

## 4. 운영에서 겪은 것

- **여러 저장소를 동시에 push하면** 매니페스트 자동 커밋 잡이 `cannot lock ref`로 실패할 수 있습니다(clone → sed → push 구조). 이미지는 이미 레지스트리에 있으므로 **해당 잡만 재실행**하면 복구됩니다.
- **롤아웃 중 503**: 옛 파드 종료 ~ 새 파드의 Eureka 등록 사이에 게이트웨이가 잠시 503을 반환합니다. 무중단(`replicas: 2` + `maxUnavailable: 0` + preStop 지연)은 다음 과제로 정리해 두었습니다.
- **Secret 누락 배포**: `auth-jwt-secret`이 없어 파드가 `CreateContainerConfigError`로 뜨지 않았는데, 이는 위 ②의 **의도된 실패**였습니다.

---

## 5. 차트 컨벤션

- 구조: `Chart.yaml` · `values.yaml` · `templates/_helpers.tpl` · `deployment.yaml` · `service.yaml` (+ 필요 시 `configmap.yaml` + `files/`)
- 리소스 이름은 헬퍼(`{{ include "<chart>.fullname" . }}`)로 생성하고 하드코딩하지 않습니다
- `resources: {}`(제한 없음)는 대부분 **의도된 설정**입니다(`argocd` 차트만 예외). 요청 없이 임의로 추가·제거하지 않습니다
- 네임스페이스는 대부분 `sj-lab` 하드코딩, `dashboard`만 파라미터화

## 주의

- `postgres`·`postgres-qfield`의 `values.yaml`에 **DB 비밀번호가 평문으로 커밋**돼 있습니다(초기 구성의 잔재). 새 차트에서는 이 패턴을 따르지 말고 Secret을 쓰며, 기존 값도 정리 대상입니다.

## 참고

- 전체 구조·배포 경로: 총괄 저장소 `mapservice-rest`의 `docs/system-architecture.md`
- Secret 목록·확인 명령: 같은 저장소의 `docs/k8s-secrets.md`
- 정적 사이트(허브·지도) 배포: 같은 저장소의 `docs/deploy-static-sites.md`
- 작업 규칙: 이 저장소의 `CLAUDE.md`
