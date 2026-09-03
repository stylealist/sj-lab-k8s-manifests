# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 저장소 개요

sj-lab 프로젝트들을 위한 **쿠버네티스 배포 매니페스트(Helm 차트) 전용 저장소**입니다. 애플리케이션 소스 코드는 없고, 최상위 디렉터리 하나가 독립된 Helm 차트 하나에 대응합니다 (`apigateway/`, `dashboard/`, `discoveryserver/`, `fast-api-ai/`, `geoserver/`, `jenkins/`, `mapservice-rest/`, `postgres/`, `postgres-qfield/`, `sj-lab-scheduler/`, `sj-lab-webserver/`, `sj-qfieldsync/`, `argocd/`). 차트 간 공용 라이브러리 차트나 umbrella 차트는 없으며, 서로 독립적으로 배포됩니다.

ArgoCD가 이 저장소를 GitOps 소스로 사용해 클러스터에 동기화합니다(`automated.selfHeal: true`, `automated.prune: true`). Jenkins CI가 각 서비스 이미지를 빌드한 뒤 해당 차트의 `values.yaml`에 있는 `image.tag`를 자동으로 올려서 커밋합니다 (예: 커밋 메시지 `Update sj-qfieldsync image tag to 2 from Jenkins`). **이 자동 커밋 패턴 때문에 `image.tag`는 Jenkins가 관리하는 값으로 취급하고, 별도 요청 없이 임의로 낮추거나 되돌리지 마세요.**

## 자주 쓰는 명령어

빌드/테스트 도구가 없는 순수 매니페스트 저장소이므로, 변경 후 검증은 Helm CLI로 합니다.

```bash
# 특정 차트 문법/베스트프랙티스 검사
helm lint <chart-dir>            # 예: helm lint sj-qfieldsync

# 렌더링 결과 확인 (values 반영된 최종 YAML)
helm template <chart-dir> -f <chart-dir>/values.yaml

# 클러스터에 적용하지 않고 API 서버 스키마로 검증만
helm template <chart-dir> | kubectl apply --dry-run=server -f -
```

차트 하나를 수정했다면 반드시 해당 차트 디렉터리에 대해 `helm lint`와 `helm template`을 실행해 렌더링이 깨지지 않는지 확인하세요. (Edit/Write 이후 `.claude/hooks/helm-lint.js`가 자동으로 `helm lint`를 실행해 결과를 알려줍니다.)

## 차트 공통 컨벤션

- **디렉터리 구조**: `Chart.yaml`, `values.yaml`, `templates/_helpers.tpl`, `templates/deployment.yaml`, `templates/service.yaml`, 필요 시 `templates/configmap.yaml` + `files/`(원본 설정 파일, `.Files.Get`으로 ConfigMap에 삽입).
- **헬퍼 템플릿**: `{{ include "<chart>.name" . }}` → `.Chart.Name`, `{{ include "<chart>.fullname" . }}` → `.Release.Name`(또는 `fullnameOverride`). 새 리소스를 추가할 때도 하드코딩 대신 이 헬퍼를 사용하세요.
- **ConfigMap 변경 시 재배포 트리거**: `configmap.yaml`이 있는 차트는 `deployment.yaml`에 아래 annotation을 넣어 ConfigMap 내용이 바뀌면 Pod가 자동 재시작되게 합니다. ConfigMap 관련 템플릿을 추가/수정할 때 이 패턴을 유지하세요.
  ```yaml
  annotations:
    configmap-checksum: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  ```
- **이미지 레지스트리**: 사내 서비스는 대부분 NCP Container Registry(`sj-lab-registry.kr.ncr.ntruss.com/<image>`)를 쓰고 `imagePullSecrets: ncp-registry-secret`로 접근합니다. 외부 이미지(geoserver, postgis, nginx, kubernetesui/dashboard 등)는 이 시크릿이 필요 없습니다.
- **리소스 제한**: 대부분의 서비스 차트는 `resources: {}` (요청/제한 없음)를 **의도적으로** 사용합니다. `argocd` 차트만 예외로 실제 requests/limits가 지정돼 있습니다. 리소스 제한을 없애거나 바꿀 때는 이유를 주석으로 남기는 관례가 있습니다 (예: `# 리소스 제한없음`). 요청받지 않은 이상 임의로 리소스 제한을 추가/제거하지 마세요.
- **네임스페이스**: 대부분 `sj-lab`을 템플릿에 하드코딩합니다. `dashboard` 차트만 `.Values.namespace`로 파라미터화(`kubernetes-dashboard`)돼 있습니다. 새 리소스를 추가할 땐 같은 차트 안의 기존 패턴을 그대로 따르세요.
- **서비스 노출**: 대부분 `NodePort`로 직접 노드 포트를 노출합니다(로컬 nginx/webserver가 리버스 프록시하는 구조로 보입니다). 내부 전용 서비스(`mapservice-rest`, `sj-lab-scheduler`, `fast-api-ai`)는 `ClusterIP`를 씁니다.
- **Spring Boot 서비스** (`apigateway`, `discoveryserver`, `mapservice-rest`, `sj-lab-scheduler`): `files/application-prod.yml`을 ConfigMap으로 마운트하고, `SPRING_PROFILES_ACTIVE` / `SPRING_CONFIG_LOCATION` 환경변수로 `classpath:/,file:/app/config/` 프로파일을 지정하는 동일한 패턴을 씁니다.
- **`argocd` 차트**: Argo CD 자체를 설치하는 차트가 아니라, Argo CD가 자기 자신을 관리하도록 하는 `Application` 리소스 하나만 정의합니다(self-management). `values.yaml`의 `server/controller/repoServer/redis/dex` 키들은 현재 `templates/application.yaml`에서 참조되지 않으니, 실제로 쓰이는 값인지 먼저 확인 없이 신뢰하지 마세요.

## 보안 관련 주의사항

`postgres/values.yaml`, `postgres-qfield/values.yaml`에 DB 비밀번호가 **평문으로 커밋**돼 있습니다. 새로운 차트나 값을 추가할 때 이 패턴을 따라 하지 말고, 가능하면 Secret 리소스나 외부 시크릿 매니저 사용을 제안하세요. 기존 평문 값을 다룰 때도 대화나 커밋 메시지, 새로 만드는 문서에 값을 그대로 옮겨 적지 마세요.

## 참고

### 차트별 요약

| 차트 | 이미지 | 노출 방식 | 비고 |
|---|---|---|---|
| `apigateway` | `sj-lab-registry/sj-lab-apigateway` | NodePort 30089 (8100) | namespace `sj-lab`, Spring |
| `argocd` | - | - | namespace `argocd`, ArgoCD self-management Application |
| `dashboard` | `kubernetesui/dashboard`, `metrics-scraper` | NodePort 32443 | namespace `kubernetes-dashboard`(파라미터화), RBAC/ServiceAccount 포함 |
| `discoveryserver` | `sj-lab-registry/sj-lab-discoveryserver` | NodePort 30087 (8761) | Eureka, Spring, `replicaCount` 고정 1 |
| `fast-api-ai` | `sj-lab-registry/fast-api-ai` | ClusterIP 80→8000 | FastAPI, Eureka client(`EUREKA_SERVER`) |
| `geoserver` | `docker.osgeo.org/geoserver` | NodePort 32180 | hostPath 볼륨, CORS 설정(webxml 패치) |
| `jenkins` | `sj-lab-registry/jenkins-with-docker` | NodePort 31880 / 32500(agent) | hostPath 기반 PV |
| `mapservice-rest` | `sj-lab-registry/mapservice-rest` | ClusterIP 8080 | Spring |
| `postgres` | `postgis/postgis` | NodePort 30017 | DB `sjlab`, hostPath 볼륨 |
| `postgres-qfield` | `postgis/postgis` | NodePort 30019 | DB `qfield`, hostPath 볼륨 |
| `sj-lab-scheduler` | `sj-lab-registry/sj-lab-scheduler` | ClusterIP 8080 | Spring |
| `sj-lab-webserver` | `nginx` | NodePort 32080 | hostPath로 정적 컨텐츠/인증서 마운트 |
| `sj-qfieldsync` | `sj-lab-registry/sj-qfieldsync` | (내부용) | Python daemon |

### sj-qfieldsync 특이사항

- `replicaCount: 1` 고정 — 동시 실행 시 다운로드 작업이 겹치며 DB Lock 충돌이 나기 때문에 **절대 스케일아웃하면 안 됩니다**.
- `deployment.yaml`의 `strategy.type: Recreate` — 이전 Pod가 완전히 종료된 뒤 새 Pod를 띄워 중복 다운로드를 방지합니다. `RollingUpdate`로 바꾸지 마세요.

### 추가된 Claude Code 설정

- `.claude/agents/reviewer.md` — 이 저장소의 컨벤션(위 내용) 기준으로 Helm 차트 변경을 검토하는 서브에이전트.
- `.claude/hooks/helm-lint.js` + `.claude/settings.json` — `templates/*.yaml` 또는 `values.yaml`을 Edit/Write한 직후 자동으로 `helm lint`를 돌려 결과를 알려주는 PostToolUse 훅.
- `.claude/skills/new-service/SKILL.md` — 이 저장소 컨벤션에 맞춰 새 서비스용 Helm 차트를 스캐폴딩하는 스킬.
