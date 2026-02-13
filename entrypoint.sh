#!/bin/bash
set -e

# ─── 디렉토리 권한 수정 (root로 실행) ───
echo "📂 디렉토리 권한 수정 중..."
for DIR in /home/node/.openclaw/shared /home/node/.openclaw/workspaces /home/node/.openclaw; do
    mkdir -p "$DIR"
    chown node:node "$DIR"
    echo "  ✅ $DIR → node:node"
done
# workspaces 하위 디렉토리도 재귀적으로 수정
chown -R node:node /home/node/.openclaw/workspaces 2>/dev/null || true
chown -R node:node /home/node/.openclaw/shared 2>/dev/null || true
echo "📂 권한 수정 완료"

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

# ─── JSONC → JSON 변환 (jq는 주석을 파싱할 수 없음) ───
echo "🔧 JSONC 주석 제거 중..."
sed -i '/^\s*\/\//d' "$TARGET"
echo "  ✅ 주석 제거 완료"

# ─── Discord Bot Token 주입 ───
# 환경변수 DISCORD_BOT_TOKEN_<AGENT_ID>를 accounts에 주입
echo "🔑 Discord Bot Token 주입 중..."
AGENTS="pm frontend backend devops security design research qa"
for AGENT in $AGENTS; do
    # 환경변수 이름: DISCORD_BOT_TOKEN_PM, DISCORD_BOT_TOKEN_FRONTEND, ...
    ENV_VAR="DISCORD_BOT_TOKEN_$(echo $AGENT | tr 'a-z' 'A-Z')"
    TOKEN_VALUE="${!ENV_VAR}"

    if [ -n "$TOKEN_VALUE" ]; then
        # jq로 accounts.<agent>.token 필드 주입
        jq --arg agent "$AGENT" --arg token "$TOKEN_VALUE" \
            '.channels.discord.accounts[$agent].token = $token' \
            "$TARGET" > /tmp/openclaw_tmp.json && mv /tmp/openclaw_tmp.json "$TARGET"
        echo "  ✅ $AGENT 봇 토큰 주입 완료"
    else
        echo "  ⚠️ $ENV_VAR 환경변수 없음 — 건너뜀"
    fi
done

# 첫 번째 토큰을 기본 Discord 토큰으로도 설정 (OpenClaw 호환)
if [ -n "$DISCORD_BOT_TOKEN_PM" ]; then
    jq --arg token "$DISCORD_BOT_TOKEN_PM" \
        '.channels.discord.token = $token' \
        "$TARGET" > /tmp/openclaw_tmp.json && mv /tmp/openclaw_tmp.json "$TARGET"
    echo "  ✅ 기본 Discord 토큰 설정 (PM)"
fi

echo "🔑 Discord 토큰 주입 완료"

# ─── 에이전트 디렉토리 + 인증 자동 설정 ───
echo "📁 에이전트 디렉토리 확인 중..."
AGENT_IDS=$(grep -o '"id": *"[^"]*"' "$TARGET" | sed 's/"id": *"\([^"]*\)"/\1/')
PM_AUTH="/home/node/.openclaw/agents/pm/agent/auth-profiles.json"

for AGENT_ID in $AGENT_IDS; do
    AGENT_DIR="/home/node/.openclaw/agents/$AGENT_ID/agent"
    if [ ! -d "$AGENT_DIR" ]; then
        mkdir -p "$AGENT_DIR"
        echo "  ✅ 에이전트 디렉토리 생성: $AGENT_ID"
    fi

    # PM의 인증 정보를 다른 에이전트에 복사 (없는 경우에만)
    AGENT_AUTH="$AGENT_DIR/auth-profiles.json"
    if [ "$AGENT_ID" != "pm" ] && [ -f "$PM_AUTH" ] && [ ! -f "$AGENT_AUTH" ]; then
        cp "$PM_AUTH" "$AGENT_AUTH"
        echo "  🔑 인증 복사: pm → $AGENT_ID"
    fi
done
echo "📁 에이전트 준비 완료"

# ─── gosu로 node 유저 전환 후 실행 ───
exec gosu node "$@"
