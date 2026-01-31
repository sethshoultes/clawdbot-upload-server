#!/usr/bin/env bash
set -euo pipefail

# Restore ClawdBot DO droplet infrastructure from backed-up configs.
# Run this ON the droplet as root after a fresh ClawdBot install.
#
# Prerequisites:
#   - ClawdBot installed at /opt/clawdbot/
#   - Caddy, oauth2-proxy, Docker, FileBrowser, FFmpeg installed
#   - Hostname set: hostnamectl set-hostname clawdbot-do
#   - This repo cloned to /home/clawdbot/upload-server/
#   - Users created: clawdbot (default), clawdbot-curtis
#
# Usage:
#   cd /home/clawdbot/upload-server
#   sudo bash deploy/restore.sh
#
# After running, you still need to:
#   1. Fill in secrets in /opt/clawdbot.env and /opt/clawdbot-curtis.env
#   2. Fill in secrets in /etc/oauth2-proxy.cfg and /etc/oauth2-proxy-curtis.cfg
#   3. Fill in secrets in /home/clawdbot/.clawdbot/clawdbot.json
#   4. Fill in secrets in /home/clawdbot-curtis/.clawdbot/clawdbot.json
#   5. Set up FileBrowser databases (see below)
#   6. Copy preview page: cp deploy/preview-index.html /opt/preview/index.html

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Restoring infrastructure configs from $DEPLOY_DIR ==="

# Caddy
echo "-> /etc/caddy/Caddyfile"
cp "$DEPLOY_DIR/Caddyfile" /etc/caddy/Caddyfile

# Systemd services — Seth
echo "-> /etc/systemd/system/clawdbot.service"
cp "$DEPLOY_DIR/clawdbot.service" /etc/systemd/system/clawdbot.service

echo "-> /etc/systemd/system/clawdbot-upload.service"
cp "$DEPLOY_DIR/clawdbot-upload.service" /etc/systemd/system/clawdbot-upload.service

# Systemd services — Curtis
echo "-> /etc/systemd/system/clawdbot-curtis.service"
cp "$DEPLOY_DIR/clawdbot-curtis.service" /etc/systemd/system/clawdbot-curtis.service

echo "-> /etc/systemd/system/clawdbot-curtis-upload.service"
cp "$DEPLOY_DIR/clawdbot-curtis-upload.service" /etc/systemd/system/clawdbot-curtis-upload.service

echo "-> /etc/systemd/system/oauth2-proxy-curtis.service"
cp "$DEPLOY_DIR/oauth2-proxy-curtis.service" /etc/systemd/system/oauth2-proxy-curtis.service

# Systemd services — FileBrowser
echo "-> /etc/systemd/system/filebrowser-seth.service"
cp "$DEPLOY_DIR/filebrowser-seth.service" /etc/systemd/system/filebrowser-seth.service

echo "-> /etc/systemd/system/filebrowser-curtis.service"
cp "$DEPLOY_DIR/filebrowser-curtis.service" /etc/systemd/system/filebrowser-curtis.service

# Control UI injection
echo "-> /opt/clawdbot/dist/control-ui/index.html (upload button script tag)"
cp "$DEPLOY_DIR/control-ui-index.html" /opt/clawdbot/dist/control-ui/index.html

# Preview page
echo "-> /opt/preview/index.html"
mkdir -p /opt/preview
cp "$DEPLOY_DIR/preview-index.html" /opt/preview/index.html

# Artifacts gallery
echo "-> /opt/canvas-gallery.html"
cp "$DEPLOY_DIR/canvas-gallery.html" /opt/canvas-gallery.html

# Templates (copy only if real files don't exist yet)

# Seth env
if [ ! -f /opt/clawdbot.env ]; then
  echo "-> /opt/clawdbot.env (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/clawdbot.env.template" /opt/clawdbot.env
else
  echo "-> /opt/clawdbot.env already exists, skipping"
fi

# Curtis env
if [ ! -f /opt/clawdbot-curtis.env ]; then
  echo "-> /opt/clawdbot-curtis.env (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/clawdbot-curtis.env.template" /opt/clawdbot-curtis.env
else
  echo "-> /opt/clawdbot-curtis.env already exists, skipping"
fi

# Seth OAuth proxy
if [ ! -f /etc/oauth2-proxy.cfg ]; then
  echo "-> /etc/oauth2-proxy.cfg (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/oauth2-proxy.cfg.template" /etc/oauth2-proxy.cfg
else
  echo "-> /etc/oauth2-proxy.cfg already exists, skipping"
fi

# Curtis OAuth proxy
if [ ! -f /etc/oauth2-proxy-curtis.cfg ]; then
  echo "-> /etc/oauth2-proxy-curtis.cfg (TEMPLATE - fill in secrets!)"
  cp "$DEPLOY_DIR/oauth2-proxy-curtis.cfg.template" /etc/oauth2-proxy-curtis.cfg
else
  echo "-> /etc/oauth2-proxy-curtis.cfg already exists, skipping"
fi

# Seth ClawdBot JSON
if [ ! -f /home/clawdbot/.clawdbot/clawdbot.json ]; then
  echo "-> /home/clawdbot/.clawdbot/clawdbot.json (TEMPLATE - fill in secrets!)"
  mkdir -p /home/clawdbot/.clawdbot
  cp "$DEPLOY_DIR/clawdbot.json.template" /home/clawdbot/.clawdbot/clawdbot.json
  chown -R clawdbot:clawdbot /home/clawdbot/.clawdbot
else
  echo "-> /home/clawdbot/.clawdbot/clawdbot.json already exists, skipping"
fi

# Curtis ClawdBot JSON
if [ ! -f /home/clawdbot-curtis/.clawdbot/clawdbot.json ]; then
  echo "-> /home/clawdbot-curtis/.clawdbot/clawdbot.json (TEMPLATE - fill in secrets!)"
  mkdir -p /home/clawdbot-curtis/.clawdbot
  cp "$DEPLOY_DIR/clawdbot-curtis.json.template" /home/clawdbot-curtis/.clawdbot/clawdbot.json
  chown -R clawdbot-curtis:clawdbot-curtis /home/clawdbot-curtis/.clawdbot
else
  echo "-> /home/clawdbot-curtis/.clawdbot/clawdbot.json already exists, skipping"
fi

# Ensure directories exist
mkdir -p /home/clawdbot/upload-server/uploads
chown -R clawdbot:clawdbot /home/clawdbot/upload-server

mkdir -p /home/clawdbot-curtis/upload-server/uploads
chown -R clawdbot-curtis:clawdbot-curtis /home/clawdbot-curtis/upload-server 2>/dev/null || true

# Skills: symlink workspace and .clawdbot skills dirs to upload-server repo
# This way git pull on the upload-server automatically updates all skills
echo "-> Symlinking skills directories"

# Seth
mkdir -p /home/clawdbot/clawd/.agents /home/clawdbot/clawd/skills
rm -rf /home/clawdbot/clawd/.agents/skills
ln -sfn /home/clawdbot/upload-server/.agents/skills /home/clawdbot/clawd/.agents/skills
rm -rf /home/clawdbot/.clawdbot/skills
ln -sfn /home/clawdbot/upload-server/.agents/skills /home/clawdbot/.clawdbot/skills
chown -h clawdbot:clawdbot /home/clawdbot/clawd/.agents/skills /home/clawdbot/.clawdbot/skills

# Curtis
mkdir -p /home/clawdbot-curtis/clawd/.agents /home/clawdbot-curtis/clawd/skills
rm -rf /home/clawdbot-curtis/clawd/.agents/skills
ln -sfn /home/clawdbot-curtis/upload-server/.agents/skills /home/clawdbot-curtis/clawd/.agents/skills
rm -rf /home/clawdbot-curtis/.clawdbot/skills
ln -sfn /home/clawdbot-curtis/upload-server/.agents/skills /home/clawdbot-curtis/.clawdbot/skills
chown -h clawdbot-curtis:clawdbot-curtis /home/clawdbot-curtis/clawd/.agents/skills /home/clawdbot-curtis/.clawdbot/skills

mkdir -p /etc/filebrowser

# Set up FileBrowser databases if they don't exist
if [ ! -f /etc/filebrowser/seth.db ]; then
  echo "-> Setting up FileBrowser for Seth"
  filebrowser config init --database /etc/filebrowser/seth.db
  filebrowser config set --database /etc/filebrowser/seth.db \
    --address 127.0.0.1 --port 8090 --root /home/clawdbot/clawd \
    --baseURL /browse --auth.method noauth
  filebrowser users add admin adminpassword1234 --database /etc/filebrowser/seth.db --perm.admin
fi

if [ ! -f /etc/filebrowser/curtis.db ]; then
  echo "-> Setting up FileBrowser for Curtis"
  filebrowser config init --database /etc/filebrowser/curtis.db
  filebrowser config set --database /etc/filebrowser/curtis.db \
    --address 127.0.0.1 --port 8091 --root /home/clawdbot-curtis/clawd \
    --baseURL /browse --auth.method noauth
  filebrowser users add admin adminpassword1234 --database /etc/filebrowser/curtis.db --perm.admin
fi

# Workspace backup
echo "-> /opt/backup-workspaces.sh"
cp "$DEPLOY_DIR/backup-workspaces.sh" /opt/backup-workspaces.sh
chmod +x /opt/backup-workspaces.sh

echo "-> /etc/systemd/system/workspace-backup.service"
cp "$DEPLOY_DIR/workspace-backup.service" /etc/systemd/system/workspace-backup.service

echo "-> /etc/systemd/system/workspace-backup.timer"
cp "$DEPLOY_DIR/workspace-backup.timer" /etc/systemd/system/workspace-backup.timer

# Reload and restart
echo "=== Reloading systemd and restarting services ==="
systemctl daemon-reload
systemctl enable clawdbot clawdbot-upload clawdbot-curtis clawdbot-curtis-upload \
  caddy oauth2-proxy oauth2-proxy-curtis filebrowser-seth filebrowser-curtis \
  workspace-backup.timer
systemctl restart caddy
systemctl restart clawdbot-upload clawdbot-curtis-upload
systemctl restart filebrowser-seth filebrowser-curtis
systemctl start workspace-backup.timer

echo ""
echo "=== Done ==="
echo "If you copied template files, edit them to fill in secrets:"
echo "  nano /opt/clawdbot.env"
echo "  nano /opt/clawdbot-curtis.env"
echo "  nano /etc/oauth2-proxy.cfg"
echo "  nano /etc/oauth2-proxy-curtis.cfg"
echo "  nano /home/clawdbot/.clawdbot/clawdbot.json"
echo "  nano /home/clawdbot-curtis/.clawdbot/clawdbot.json"
echo "Then restart: systemctl restart clawdbot clawdbot-curtis oauth2-proxy oauth2-proxy-curtis"
