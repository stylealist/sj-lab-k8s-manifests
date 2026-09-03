---
name: new-service
description: 이 저장소(sj-lab k8s Helm 매니페스트)의 기존 컨벤션에 맞춰 새 서비스용 Helm 차트를 스캐폴딩합니다. "새 서비스 차트 추가해줘", "새 마이크로서비스 배포 매니페스트 만들어줘" 같은 요청에 사용하세요.
---

# 새 서비스 Helm 차트 만들기

이 저장소의 각 최상위 디렉터리는 독립된 Helm 차트입니다. 새 서비스를 추가할 때는 처음부터 새로 설계하지 말고, **성격이 가장 비슷한 기존 차트를 템플릿으로 삼아 복사 후 수정**하세요.

## 1. 참고할 기존 차트 고르기

- Spring Boot 서비스(설정 파일을 `files/application-prod.yml`로 마운트) → `mapservice-rest/` 또는 `sj-lab-scheduler/`
- Python/FastAPI 서비스 → `fast-api-ai/`
- 상태를 가지는 daemon/singleton 서비스 → `sj-qfieldsync/`

대상 파일을 먼저 Read로 열어서 구조를 확인한 뒤 진행하세요.

## 2. 디렉터리 구성

```
<service-name>/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl
    deployment.yaml
    service.yaml
    configmap.yaml      # 설정 파일을 마운트해야 하는 경우만
  files/
    application-prod.yml  # 또는 config.yaml 등, configmap.yaml이 .Files.Get으로 읽는 원본
```

## 3. 각 파일 작성 규칙 (CLAUDE.md 컨벤션 준수)

- **Chart.yaml**: `apiVersion: v2`, `name: <service-name>`, `type: application`, `version`/`appVersion`은 `0.1.0`/`"1.0"`처럼 작게 시작.
- **_helpers.tpl**: 다른 차트와 동일한 패턴 사용.
  ```
  {{- define "<service-name>.name" -}}
  {{ .Chart.Name }}
  {{- end }}

  {{- define "<service-name>.fullname" -}}
  {{ .Release.Name }}
  {{- end }}
  ```
- **values.yaml**:
  - `image.repository`: 사내 서비스면 `sj-lab-registry.kr.ncr.ntruss.com/<service-name>`, 이미지 태그는 초기값 `1`(이후 Jenkins가 자동 갱신).
  - `image.pullSecret: ncp-registry-secret` (사내 레지스트리인 경우).
  - `resources: {}` 기본값 유지 — 별도로 제한이 필요하다는 요청이 없으면 추가하지 마세요.
  - `service.type`: 외부 노출이 필요하면 `NodePort`(+ 미사용 nodePort 번호 확인 필요, 아래 참고), 내부 전용이면 `ClusterIP`.
- **deployment.yaml**:
  - `metadata.name`, `spec.selector`, `template.labels` 모두 `{{ include "<service-name>.fullname" . }}` / `{{ include "<service-name>.name" . }}` 헬퍼 사용.
  - `namespace: sj-lab` (이 저장소의 사내 서비스 대부분이 사용하는 값 — 다른 값이 필요하면 사용자에게 확인).
  - `configmap.yaml`이 있다면 `configmap-checksum` annotation을 반드시 추가:
    ```yaml
    annotations:
      configmap-checksum: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    ```
  - `imagePullSecrets`에 `.Values.image.pullSecret`(또는 `pullSecrets` 리스트) 연결.
- **service.yaml**: 포트/nodePort는 `values.yaml`의 값을 그대로 참조.

## 4. 검증

파일을 다 만든 뒤 반드시 실행하고 결과를 확인하세요.

```bash
helm lint <service-name>
helm template <service-name> -f <service-name>/values.yaml
```

`.claude/hooks/helm-lint.js` 훅이 Edit/Write 직후 자동으로 `helm lint`를 실행해 결과를 알려주지만, 최종적으로는 `helm template` 렌더링 결과를 직접 눈으로 한 번 확인하세요.

## 5. 사용 중인 NodePort 확인

`NodePort`를 새로 할당하기 전에 기존 값과 충돌하지 않는지 확인하세요.

```bash
grep -rn "nodePort" --include="values.yaml" .
```

## 6. 하지 말아야 할 것

- 비밀번호/토큰을 `values.yaml`에 평문으로 넣지 마세요 (기존 `postgres`, `postgres-qfield`의 평문 비밀번호는 알려진 예외이며 새로 따라 하면 안 됩니다).
- ArgoCD `Application` 리소스를 이 저장소 안에 새로 만들지 마세요 — 이 저장소에는 `argocd` 차트 자신의 self-management `Application`만 있고, 각 서비스를 가리키는 `Application`은 포함돼 있지 않습니다. 새 서비스를 클러스터에 실제로 배포하려면 어디에 `Application`을 등록해야 하는지 사용자에게 먼저 확인하세요.
