#!/bin/bash
# ===========================
# 개포히치하이커스 — Docker 초기 셋업 스크립트
# ===========================
# 미니PC에서 최초 1회 실행
# OpenAI Codex OAuth 인증 + OpenClaw 온보딩 자동화

set -e

echo "🚀 개포히치하이커스 — Docker 셋업 시작"
echo ""

# ─── Step 1: .env 확인 ───
if [ ! -f .env ]; then
    echo "⚠️  .env 파일이 없습니다. .env.example에서 복사합니다."
    cp .env.example .env
    echo "📝 .env 파일이 생성되었습니다."
    echo "   OpenAI Codex OAuth를 사용하므로 API 키는 필요 없습니다."
    echo ""
fi

# ─── Step 2: Docker 이미지 빌드 ───
echo "🔨 Docker 이미지 빌드 중..."
docker compose build
echo "✅ 이미지 빌드 완료"
echo ""

# ─── Step 3: 온보딩 (인터랙티브) ───
echo "🎯 OpenClaw 온보딩을 시작합니다."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 OpenAI Codex OAuth 인증 안내:"
echo ""
echo "  1. 온보딩 중 AI 프로바이더로 'OpenAI' 선택"
echo "  2. 인증 방식으로 'OpenAI Code (Codex) subscription' 선택"
echo "  3. 터미널에 OAuth URL이 출력됩니다"
echo "  4. 해당 URL을 이 PC의 브라우저에서 열고 OpenAI 계정으로 로그인"
echo "  5. 인증 완료 후 자동으로 토큰이 저장됩니다"
echo ""
echo "  💡 또는 CLI에서 직접 인증:"
echo "     openclaw onboard --auth-choice openai-codex"
echo "     openclaw models auth login --provider openai-codex"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 온보딩 실행 (인터랙티브 모드 — 터미널 입력 필요)
docker compose run --rm -it openclaw-gateway openclaw onboard --auth-choice openai-codex

echo ""
echo "✅ 온보딩 완료!"
echo ""

# ─── Step 3.5: Doctor 자동 수정 ───
echo "🔧 설정 자동 수정 중..."
docker compose run --rm openclaw-gateway openclaw doctor --fix
echo "✅ doctor --fix 완료"
echo ""

# ─── Step 4: Gateway 기동 ───
echo "🚀 Gateway + Browser 컨테이너 시작..."
docker compose up -d
echo ""

# ─── Step 5: 상태 확인 ───
echo "📊 컨테이너 상태:"
docker compose ps
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 개포히치하이커스 셋업 완료!"
echo ""
echo "  📡 Gateway:  http://127.0.0.1:18789"
echo "  🔍 로그 확인: docker compose logs -f"
echo "  🛑 중지:      docker compose down"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
