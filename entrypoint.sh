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

exec "$@"
