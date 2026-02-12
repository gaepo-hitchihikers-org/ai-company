#!/bin/bash
set -e

TARGET="/home/node/.openclaw/openclaw.json"
SOURCE="/config/openclaw.json"

if [ ! -f "$TARGET" ]; then
    cp "$SOURCE" "$TARGET"
    echo "✅ openclaw.json 초기 복사 완료"
    echo "🔧 doctor --fix 실행 중..."
    openclaw doctor --fix || echo "⚠️ doctor --fix 실패 (계속 진행)"
elif ! cmp -s "$SOURCE" "$TARGET" 2>/dev/null; then
    # config가 변경됐으면 업데이트
    cp "$SOURCE" "$TARGET"
    echo "🔄 openclaw.json 업데이트 완료"
    echo "🔧 doctor --fix 실행 중..."
    openclaw doctor --fix || echo "⚠️ doctor --fix 실패 (계속 진행)"
else
    echo "ℹ️ openclaw.json 변경 없음 — 건너뜀"
fi

# ─── 에이전트 디렉토리 자동 생성 ───
# openclaw.json에서 에이전트 ID를 추출하여 agentDir 생성
echo "📁 에이전트 디렉토리 확인 중..."
AGENT_IDS=$(grep -o '"id": *"[^"]*"' "$TARGET" | sed 's/"id": *"\([^"]*\)"/\1/')
for AGENT_ID in $AGENT_IDS; do
    AGENT_DIR="/home/node/.openclaw/agents/$AGENT_ID/agent"
    if [ ! -d "$AGENT_DIR" ]; then
        mkdir -p "$AGENT_DIR"
        echo "  ✅ 에이전트 디렉토리 생성: $AGENT_ID"
    fi
done
echo "📁 에이전트 디렉토리 준비 완료"

exec "$@"

