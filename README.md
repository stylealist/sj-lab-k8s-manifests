# sj-lab-k8s-manifests — Kubernetes 매니페스트 및 GitOps 배포 저장소

`sj-lab-k8s-manifests`는 sj-lab 분산 플랫폼의 전체 인프라 리소스와 마이크로서비스 배포 명세를 관리하는 Helm 차트 저장소이자, ArgoCD가 참조하는 단일 진실 공급원(Single Source of Truth, SSOT)입니다.

---

## 1. 저장소 역할 및 핵심 책임

- **GitOps 배포 자동화의 단일 진실 공급원**: 모든 클러스터 워크로드(백엔드, 게이트웨이, 배치, DB 등)의 상태를 선언적 Helm 차트로 정의하고 ArgoCD를 통해 실시간 자동 동기화(Auto-Sync)합니다.
- **CI/CD 파이프라인 연계**: Jenkins 파이프라인에서 컨테이너 이미지를 빌드/푸시한 후, 본 저장소의 `values.yaml` 내 `image.tag`를 자동 갱신하여 클러스터 무중단 롤아웃을 트리거합니다.
- **설정 및 기밀정보(Secret) 외부화 관리**: 운영 설정(`application-prod.yml`)을 ConfigMap으로 분리하고, 인증 토큰 및 DB 패스워드 등 민감정보를 Kubernetes Secret으로 격리 주입합니다.

---

## 2. 배포 아키텍처 및 CI/CD 파이프라인

### 2.1 GitOps 기반 배포 흐름도

```
[개발자 소스 Push] (개별 서비스 Repo)
       │
       ▼ Webhook
[Jenkins CI Server]
  ├── 1. 소스 빌드 및 단위 테스트
  ├── 2. Docker 이미지 빌드 및 태깅
  ├── 3. NCP Container Registry 푸시 (sj-lab-registry.kr.ncr.ntruss.com)
  └── 4. [sj-lab-k8s-manifests] Clone 후 values.yaml 의 image.tag 수정 및 자동 Push
               │
               ▼ Git 변경 감지
[ArgoCD GitOps Engine]
  ├── 1. 선언된 Helm 차트와 실제 클러스터 상태 비교 (Diff)
  ├── 2. Auto-Sync 트리거 (Self-Heal, Prune 활성화)
  └── 3. Kubernetes 리소스 롤링 업데이트 (RollingUpdate)
               │
               ▼
[Kubernetes Cluster (sj-lab Namespace)]
```

---

## 3. 관리 대상 Helm 차트 목록

| 차트 디렉터리 | 대상 서비스 | 쿠버네티스 서비스 타입 | 비고 |
|---|---|---|---|
| `apigateway` | Spring Cloud Gateway | NodePort (30089 -> 8100) | 플랫폼 단일 진입점 |
| `discoveryserver` | Netflix Eureka Server | NodePort (30087 -> 8761) | 서비스 레지스트리 (단일 복제본) |
| `mapservice-rest` | 지도/시설물 GeoJSON API | ClusterIP (8080) | GIS 백엔드 서비스 |
| `sj-lab-scheduler` | 공공데이터 수집 배치 | ClusterIP (8080) | 정기 크론 수집 배치 |
| `sj-lab-authserver` | 중앙 인증 / SSO | ClusterIP (8080) | JWT 발급 및 위임 인증 |
| `fast-api-ai` | Python AI 마이크로서비스 | ClusterIP (80 -> 8000) | Uvicorn 기반 서빙 |
| `sj-qfieldsync` | 현장 데이터 동기화 워커 | Deployment (단독 백그라운드) | 30초 주기 동기화 프로세스 |
| `sj-lab-webserver` | NGINX 정적 웹서버 | NodePort (32080) | 정적 웹(허브, 지도) 서빙 |
| `postgres` / `postgres-qfield` | PostGIS 데이터베이스 | ClusterIP (5432) | 공간 데이터 및 QField 동기화 DB |
| `argocd` / `jenkins` / `dashboard` | DevOps 도구군 | ClusterIP / NodePort | 클러스터 운영 및 CI/CD 플랫폼 |

---

## 4. 핵심 엔지니어링 구현 상세

### 4.1 ConfigMap 체크섬 기반 무중단 롤링 업데이트
Spring 마이크로서비스의 환경 설정(`files/application-prod.yml`)이 ConfigMap으로 마운트되는 구조에서, 설정 파일만 변경되었을 때 파드가 이를 즉시 인식하여 재기동되도록 Deployment 템플릿에 ConfigMap 체크섬 애노테이션을 적용했습니다:

```yaml
spec:
  template:
    metadata:
      annotations:
        configmap-checksum: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```
이를 통해 설정 변경 시 별도의 수동 재시작 명령 없이도 Kubernetes가 새로운 설정을 반영한 Pod로 안전하게 롤링 업데이트를 수행합니다.

### 4.2 시크릿(Secret) 주입 정책 및 Fail-Fast 설계
기밀정보 누락으로 인해 서비스가 불완전하게 동작하는 것을 방지하기 위해 중요도에 따른 엄격한 주입 정책을 적용했습니다:
- **필수 시크릿 (`auth-jwt-secret`, `ncp-registry-secret`)**: 미주입 시 파드 기동을 강제 차단(`CreateContainerConfigError`)하여 안전하지 않은 기본값으로 서비스가 구동되는 보안 사고를 원천 방지.
- **선택적 시크릿 (`qfield-credentials`, `auth-demo-credentials`)**: `optional: true` 설정을 적용하여 외부 서비스 계정이 일시적으로 부재하더라도 핵심 API는 정상 작동하고 부가 기능(원격 미디어 중계 등)만 부분 비활성화(503)되도록 설계.

---

## 5. 차트 검증 및 유지보수 가이드

### 매니페스트 린트 및 렌더링 검증
차트 템플릿을 수정한 후 클러스터 배포 전 유효성을 검증하는 표준 절차입니다:
```bash
# 문법 린트 검증
helm lint <chart_name>

# 템플릿 렌더링 결과 확인
helm template <chart_name> -f <chart_name>/values.yaml

# 클러스터 Dry-Run 검증
helm template <chart_name> | kubectl apply --dry-run=server -f -
```

> **주의**: Jenkins에 의해 `values.yaml`의 `image.tag`가 수시로 커밋되므로, 로컬에서 매니페스트 수정 전 반드시 `git pull --rebase`를 수행하여 원격 최신 상태를 동기화해야 합니다.
