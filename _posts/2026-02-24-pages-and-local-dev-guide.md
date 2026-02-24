---
title: "Git으로 페이지(포스트) 추가 + 로컬 테스트 가이드 (Windows/Linux)"
date: 2026-02-24 14:55:00 +0900
author: joseph
categories: [Guide, posts]
tags: [jekyll, chirpy, github-pages, windows, linux, docker, ruby]
---

팀에서 새 글(페이지)을 추가하는 표준 흐름은 아래처럼 하면 됩니다.

1) 레포에 새 파일을 추가한다 (`_posts/...`)<br>
2) 로컬에서 한 번 띄워서 확인한다 (아래 1.4 / 2.3)<br>
3) `git add/commit/push` 한다<br>
4) GitHub Actions가 자동으로 빌드/배포한다<br>

---

## 0) 새 페이지(포스트) 만들기

Chirpy(Jekyll)에서 “블로그 글”은 `_posts` 폴더에 아래 규칙으로 파일을 만들면 됩니다.

- 경로: `_posts/YYYY-MM-DD-슬러그.md`
- 예시: `_posts/2026-02-24-my-first-post.md`

최소 템플릿:

```markdown
---
title: "내 첫 글"
date: 2026-02-24 00:00:00 +0900
categories: [Depth1, Depth2]
author: {Name alias which is set in /_data/origin/authors.yml}
tags: [weekly]
---

여기에 내용을 작성합니다.
```

> 날짜/타임존은 팀 컨벤션에 맞춰 조정하세요.
{: .prompt-tip }

---

## 1) Windows 기준 (Ruby로 로컬 실행)

### 1.1 Ruby 설치

- 다운로드: https://rubyinstaller.org/downloads/

Ruby 버전은 아래 파일들에서 맞춰주세요. (26/02/24 기준 `3.3.10`)

- `jekyll-theme-chirpy/.github/workflows/ci.yml`
- `jekyll-theme-chirpy/.github/workflows/starter/pages-deploy.yml`
- `jekyll-theme-chirpy/jekyll-theme-chirpy.gemspec`

> 우리 레포가 theme을 업데이트하면 Ruby 버전도 바뀔 수 있어요. 항상 위 파일 기준으로 맞추는 걸 권장합니다.
{: .prompt-info }

### 1.2 RubyInstaller 설치 후 필수 체크

Ruby 설치가 끝나면 뜨는 창(기본적으로 `ridk install`)에서 **1, 2, 3을 각각 한 번씩 선택**해서 진행합니다.

### 1.3 소스 받기

```bash
git clone https://github.com/orchestration-works/orchworks.github.io.git
cd orchworks.github.io
```

### 1.4 번들 설치

PowerShell(또는 CMD)에서 레포 루트로 이동 후 실행:

```powershell
bundle config set --global jobs 1
bundle config set --global retry 3
bundle config set --local path vendor/bundle
bundle install
```

### 1.4 로컬 서버 실행

```powershell
bundle exec jekyll serve
```

- 정상 실행되면 브라우저에서 `http://localhost:4000` 로 확인
- 로컬에서 확인이 끝나면 `git push` 하면 됩니다 → Actions가 알아서 빌드/배포합니다

---

## 2) Linux 기준 (Docker로 로컬 실행)

우리 팀에서 **Linux 로컬 테스트**는 아래의 “2.3 번들 설치 + 서버 실행” 커맨드로 진행하면 됩니다.
{: .prompt-tip }

### 2.1 소스 받기

```bash
git clone https://github.com/orchestration-works/orchworks.github.io.git
cd orchworks.github.io
```

### 2.2 이미지 빌드

```bash
docker build -t orchworks-jekyll:3.3 -f Dockerfile.jekyll .
```

### 2.3 번들 설치 + 서버 실행

```bash
docker run --rm -it \
  -p 4000:4000 -p 35729:35729 \
  -v "$PWD":/work -w /work \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  orchworks-jekyll:3.3 \
  bash -lc '
    bundle config set --local path vendor/bundle
    bundle install
    bash tools/run.sh --host 0.0.0.0
  '
```

> 만약 `./tools/test.sh` 나 `./tools/run.sh` 실행에서 권한 오류가 나면(예: `Permission denied`) 아래를 한 번만 실행하세요.
{: .prompt-warning }

```bash
chmod +x tools/*.sh
```

- 실행 후 브라우저에서 `http://localhost:4000` 접속

> Windows에서도 Docker로 돌릴 수 있지만, 팀 표준은 Windows=RubyInstaller / Linux=Docker로 두는 걸 추천합니다.
{: .prompt-tip }

---

## 3) 커밋/푸시 (공통)

새 글을 추가했으면:

```bash
git status
git add _posts/<새파일>.md
git commit -m "docs: add local dev guide"
git push
```

이후 GitHub Actions가 자동으로 빌드하고, 페이지에 반영됩니다.

---

## (선택) JS/CSS 에셋 빌드가 필요할 때

로컬 실행 중 아래처럼 에러가 보이면:

- `ERROR '/assets/js/dist/theme.min.js' not found`

JS/CSS 빌드를 한 번 해주면 화면이 정상적으로 보입니다.

```bash
npm install
npm run build
```

개발 중 자동 빌드를 원하면(별도 터미널):

```bash
npm run watch:js
```
