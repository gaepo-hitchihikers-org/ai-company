#!/bin/bash
set -e

# 최초 실행 시에만 openclaw.json 복사 (이후 doctor --fix 변경사항 보존)
if [ ! -f /home/node/.openclaw/openclaw.json ]; then
    cp /config/openclaw.json /home/node/.openclaw/openclaw.json
    echo "✅ openclaw.json 초기 복사 완료"
else
    echo "ℹ️ openclaw.json 이미 존재 — 건너뜀"
fi

exec "$@"
