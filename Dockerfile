FROM node:22-bookworm-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw (2026.2.9 고정 — 2026.2.12에 multi-agent session path 버그 있음)
RUN npm install -g openclaw@2026.2.9

# Create openclaw user home structure
RUN mkdir -p /home/node/.openclaw/workspace \
    /home/node/.openclaw/workspaces \
    /home/node/.openclaw/shared \
    && chown -R node:node /home/node/.openclaw

# Entrypoint script (config 복사 + 시작)
COPY --chown=node:node entrypoint.sh /entrypoint.sh

USER node
WORKDIR /home/node

# Gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD openclaw health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["openclaw", "gateway", "--port", "18789", "--verbose"]
