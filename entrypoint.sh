#!/bin/bash
set -e

# openclaw.json을 볼륨 안으로 복사 (atomic rename 가능하도록)
if [ -f /config/openclaw.json ]; then
    cp /config/openclaw.json /home/node/.openclaw/openclaw.json
    echo "✅ openclaw.json 복사 완료"
fi

# 워크스페이스 심볼릭 링크가 없으면 생성
if [ ! -d /home/node/.openclaw/workspaces ]; then
    ln -s /workspaces /home/node/.openclaw/workspaces
fi

exec "$@"
