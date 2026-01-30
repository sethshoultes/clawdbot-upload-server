#!/usr/bin/env bash
set -euo pipefail

# Restore ClawdBot DO droplet infrastructure from backed-up configs.
# Run this ON the droplet as root after a fresh ClawdBot install.
#
# Prerequisites:
#   - ClawdBot installed at /opt/clawdbot/
#   - Caddy, oauth2-proxy, Docker installed
#   - This repo cloned to /home/clawdbot/upload-server/
#
# Usage:
#   cd /home/clawdbot/upload-server
#   sudo bash deploy/restore.sh
#
# After running, you still need to:
#   1. Fill in secrets in /opt/clawdbot.env (API keys, tokens)
#   2. Fill in secrets in /etc/oauth2-proxy.cfg (OAuth client_secret, cookie_secret)
#   3. Fill in secrets in /home/clawdbot/.clawdbot/clawdbot.json (gateway token, telegram token)

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Restoring infrastructure configs from $DEPLOY_DIR ==="

# Caddy
echo "-> /etc/caddy/Caddyfile"
cp "$DEPLOY_DIR/Caddyfile" /etc/caddy/Caddyfile

# Systemd services
echo "-> /etc/systemd/system/clawdbot.service"
cp "$DEPLOY_DIR/clawdbot.service" /etc/systemd/system/clawdbot.service

echo "-> /etc/systemd/system/clawdbot-upload.service"
cp "$DEPLOY_DIR/clawdbot-upload.service" /etc/systemd/system/clawdbot-upload.service

# Control UI injection
echo "-> /opt/clawdbot/dist/control-ui/index.html (upload button script tag)"
cp "$DEPLOY_DIR/control-ui-index.html" /opt/clawdbot/dist/control-ui/index.html

# Templates (copy only if real files don't exist yet)
if [ ! -f /opt/clawdbot.env ]; then
  echo "-> /opt/clawdbot.env (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/clawdbot.env.template" /opt/clawdbot.env
else
  echo "-> /opt/clawdbot.env already exists, skipping"
fi

if [ ! -f /etc/oauth2-proxy.cfg ]; then
  echo "-> /etc/oauth2-proxy.cfg (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/oauth2-proxy.cfg.template" /etc/oauth2-proxy.cfg
else
  echo "-> /etc/oauth2-proxy.cfg already exists, skipping"
fi

if [ ! -f /home/clawdbot/.clawdbot/clawdbot.json ]; then
  echo "-> /home/clawdbot/.clawdbot/clawdbot.json (TEMPLATE - fill in secrets!)"
  mkdir -p /home/clawdbot/.clawdbot
  cp "$DEPLOY_DIR/clawdbot.json.template" /home/clawdbot/.clawdbot/clawdbot.json
  chown -R clawdbot:clawdbot /home/clawdbot/.clawdbot
else
  echo "-> /home/clawdbot/.clawdbot/clawdbot.json already exists, skipping"
fi

# Ensure uploads dir exists
mkdir -p /home/clawdbot/upload-server/uploads
chown -R clawdbot:clawdbot /home/clawdbot/upload-server

# Reload and restart
echo "=== Reloading systemd and restarting services ==="
systemctl daemon-reload
systemctl enable clawdbot clawdbot-upload caddy oauth2-proxy
systemctl restart caddy
systemctl restart clawdbot-upload

echo ""
echo "=== Done ==="
echo "If you copied template files, edit them to fill in secrets:"
echo "  nano /opt/clawdbot.env"
echo "  nano /etc/oauth2-proxy.cfg"
echo "  nano /home/clawdbot/.clawdbot/clawdbot.json"
echo "Then restart: systemctl restart clawdbot oauth2-proxy"
