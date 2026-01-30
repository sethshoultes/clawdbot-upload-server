#!/usr/bin/env bash
set -euo pipefail

# Daily backup of ClawdBot workspace directories.
# Keeps 7 daily snapshots. Run via systemd timer (workspace-backup.timer).
#
# To add offsite backup (DO Spaces, S3, etc.):
#   1. apt install rclone && rclone config
#   2. Uncomment the rclone sync line at the bottom
#   3. Restart the timer: systemctl restart workspace-backup.timer

BACKUP_DIR="/var/backups/workspaces"
KEEP_DAYS=7
DATE=$(date +%Y-%m-%d)

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting workspace backup..."

# Back up Seth workspace
if [ -d /home/clawdbot/clawd ]; then
  tar czf "$BACKUP_DIR/seth-$DATE.tar.gz" -C /home/clawdbot clawd/
  echo "  -> seth-$DATE.tar.gz ($(du -sh "$BACKUP_DIR/seth-$DATE.tar.gz" | cut -f1))"
fi

# Back up Curtis workspace
if [ -d /home/clawdbot-curtis/clawd ]; then
  tar czf "$BACKUP_DIR/curtis-$DATE.tar.gz" -C /home/clawdbot-curtis clawd/
  echo "  -> curtis-$DATE.tar.gz ($(du -sh "$BACKUP_DIR/curtis-$DATE.tar.gz" | cut -f1))"
fi

# Rotate: delete backups older than KEEP_DAYS
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$KEEP_DAYS -delete

echo "[$(date)] Backup complete. Current snapshots:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "  (none)"

# Offsite sync (uncomment after configuring rclone):
# rclone sync "$BACKUP_DIR" do-spaces:clawdbot-backups/workspaces/ --transfers 4
