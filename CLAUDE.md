# ClawdBot Upload Server

## Project Overview
A file upload server and floating UI button for ClawdBot's Control UI. Users can upload files (images, docs, media) via a paperclip button or drag-and-drop, and the file path/URL gets inserted into the chat textarea for ClawdBot to process.

## GitHub Repo
- **Repo:** https://github.com/sethshoultes/clawdbot-upload-server
- **Branch:** `master`
- **CI/CD:** GitHub Actions deploys to DO droplet on push to `master`
- **Secrets required:** `DO_HOST`, `DO_USER`, `DO_SSH_KEY`

## AI Platforms Configured
| Platform | Env Var | Use Case |
|---|---|---|
| **Anthropic** | `ANTHROPIC_API_KEY` | Primary model (Claude Opus 4.5) — reasoning, coding, chat |
| **OpenAI** | `OPENAI_API_KEY` | DALL-E image generation, Whisper transcription, TTS |
| **Google Gemini** | `GOOGLE_API_KEY` | Gemini models, Imagen image generation, Veo video |
| **WordPress** | `WP_SITE_URL`, `WP_USERNAME`, `WP_APP_PASSWORD` | wp-publish skill — REST API publishing |

Keys are set in `/opt/clawdbot.env` on DO and in `~/.zshrc` locally. Never commit live keys — use `<PLACEHOLDER>` values in templates.

## Architecture
- `server.js` — Node.js HTTP server (zero dependencies, ES modules), port 3456
- `upload-button.js` — Client-side injection script (paperclip button inline left of textarea, drag-and-drop)
- `uploads/` — Temporary uploaded files (disposable, gitignored)
- `deploy/` — DO droplet infrastructure config backup and restore script
- `.github/workflows/deploy.yml` — CI/CD pipeline
- Script is injected into ClawdBot's Control UI `index.html` via a `<script>` tag

## Environment Configuration (unified codebase)
One codebase serves both local dev and production. Behavior is controlled by:

- **`server.js`** uses `PUBLIC_BASE_URL` env var:
  - **Unset (local):** returns local filesystem paths (ClawdBot reads files directly)
  - **Set (DO):** returns `${PUBLIC_BASE_URL}/files/<filename>` HTTPS URLs
- **`upload-button.js`** auto-detects `UPLOAD_URL` based on `location.hostname`:
  - **localhost/127.0.0.1:** `http://127.0.0.1:3456/upload` (cross-origin)
  - **Production:** `/upload` (relative, routed through Caddy)

## Two Deployment Targets

### Local Development
- Start: `node server.js`
- `PUBLIC_BASE_URL`: unset
- Inject script tag into local ClawdBot Control UI `index.html`:
  ```html
  <script src="http://127.0.0.1:3456/upload-button.js" defer></script>
  ```

### DigitalOcean Droplet (production, multi-instance team access)
- Hostname: `clawdbot-do` (shortened to avoid mDNS 63-byte label limit)
- Droplet size: `s-2vcpu-4gb-120gb-intel` ($32/mo)
- Upload server cloned from this repo to `/home/clawdbot/upload-server/`

#### Multi-Instance Setup (per-user subdomains)
Each team member gets their own ClawdBot instance with separate gateway, upload server, OAuth proxy, and workspace.

| Instance | Subdomain | Gateway | Upload | OAuth | FileBrowser |
|---|---|---|---|---|---|
| **Seth** | `seth.64-23-141-85.nip.io` | 18789 | 3456 | 4180 | 8090 |
| **Curtis** | `curtis.64-23-141-85.nip.io` | 18790 | 3457 | 4182 | 8091 |

- `64-23-141-85.nip.io` redirects to Seth's subdomain

#### Droplet Services (systemd)
| Service | Description | Port |
|---|---|---|
| `clawdbot.service` | Seth's gateway | 18789 |
| `clawdbot-curtis.service` | Curtis's gateway | 18790 |
| `clawdbot-upload.service` | Seth's upload server | 3456 |
| `clawdbot-curtis-upload.service` | Curtis's upload server | 3457 |
| `oauth2-proxy.service` | Seth's OAuth (@caseproof.com) | 4180 |
| `oauth2-proxy-curtis.service` | Curtis's OAuth (@caseproof.com) | 4182 |
| `filebrowser-seth.service` | Seth's FileBrowser | 8090 |
| `filebrowser-curtis.service` | Curtis's FileBrowser | 8091 |
| `caddy.service` | Reverse proxy, HTTPS | 443 |
| `workspace-backup.timer` | Daily workspace backups (3am UTC) | — |

#### ClawdBot Config
- Sandbox: `"mode": "off"` (runs directly on host, not Docker — enables Node.js, FFmpeg, Remotion)
- Model: `anthropic/claude-opus-4-5`
- Custom instructions via `AGENTS.md` in each workspace (NOT CLAUDE.md)
- FFmpeg installed on host for video rendering

#### Skills Deployment
Skills live in `.agents/skills/` in this repo. On DO, workspace and `.clawdbot` skills directories are **symlinks** to the upload-server repo:
- `~/clawd/.agents/skills/` → `~/upload-server/.agents/skills/`
- `~/.clawdbot/skills/` → `~/upload-server/.agents/skills/`
- `~/clawd/skills/<name>` → `../.agents/skills/<name>` (relative symlinks, committed in repo)

This means `git pull` on the upload-server automatically updates all skills — no manual copy needed. The CI/CD pipeline pulls the repo for both users, so new skills deploy automatically.

#### Caddy Routes (per subdomain)
| Route | Target |
|---|---|
| `/upload` | Upload server (upload endpoint) |
| `/upload-button.js` | Upload server (injection script) |
| `/files/*` | Upload server (serve uploaded files) |
| `/workspace/*` | Static files from workspace (raw file access) |
| `/preview/*` | Preview page (renders markdown as HTML, displays media) |
| `/browse/*` | FileBrowser (web file manager, noauth behind OAuth) |
| `/canvas/` | Artifacts gallery (lists all HTML/SVG artifacts) |
| `/canvas/*` | Static files from workspace canvas directory |
| `/*` (default) | oauth2-proxy → ClawdBot gateway |

#### Content Access
- **Preview:** `https://<subdomain>/preview/<path>` — formatted view (markdown → HTML, video player, image display)
- **Browse:** `https://<subdomain>/browse/` — web file manager UI
- **Raw:** `https://<subdomain>/workspace/<path>` — direct file download
- Preview page: `/opt/preview/index.html` (client-side marked.js rendering)
- FileBrowser: noauth mode (OAuth already protects access), databases in `/etc/filebrowser/`

## Deployment

### Automatic (CI/CD)
Push to `master` → GitHub Actions SSHes into droplet → `git pull` → `systemctl restart clawdbot-upload`

### Manual
```bash
ssh -i ~/.ssh/digitalocean_caseproof root@64.23.141.85
cd /home/clawdbot/upload-server
git pull origin master
sudo systemctl restart clawdbot-upload
```

## Infrastructure Backup (`deploy/` directory)
All DO droplet config is version-controlled in `deploy/`. To rebuild the droplet from scratch:

1. Install ClawdBot, Caddy, oauth2-proxy, FileBrowser, FFmpeg on a fresh droplet
2. Set hostname: `hostnamectl set-hostname clawdbot-do`
3. Clone this repo to `/home/clawdbot/upload-server/`
4. Run `sudo bash deploy/restore.sh`
5. Fill in secrets in the template files (API keys, OAuth secrets, tokens)
6. Create users, set up FileBrowser databases, copy preview page
7. Restart services

### What's backed up
**Committed as-is (no secrets):**
- `deploy/Caddyfile` → `/etc/caddy/Caddyfile`
- `deploy/clawdbot.service` → `/etc/systemd/system/clawdbot.service`
- `deploy/clawdbot-upload.service` → `/etc/systemd/system/clawdbot-upload.service`
- `deploy/clawdbot-curtis.service` → `/etc/systemd/system/clawdbot-curtis.service`
- `deploy/clawdbot-curtis-upload.service` → `/etc/systemd/system/clawdbot-curtis-upload.service`
- `deploy/oauth2-proxy-curtis.service` → `/etc/systemd/system/oauth2-proxy-curtis.service`
- `deploy/filebrowser-seth.service` → `/etc/systemd/system/filebrowser-seth.service`
- `deploy/filebrowser-curtis.service` → `/etc/systemd/system/filebrowser-curtis.service`
- `deploy/control-ui-index.html` → `/opt/clawdbot/dist/control-ui/index.html`
- `deploy/preview-index.html` → `/opt/preview/index.html`
- `deploy/canvas-gallery.html` → `/opt/canvas-gallery.html`
- `deploy/backup-workspaces.sh` → `/opt/backup-workspaces.sh`
- `deploy/workspace-backup.service` → `/etc/systemd/system/workspace-backup.service`
- `deploy/workspace-backup.timer` → `/etc/systemd/system/workspace-backup.timer`

**Templates with `<PLACEHOLDER>` values (fill in secrets after restore):**
- `deploy/clawdbot.env.template` → `/opt/clawdbot.env`
- `deploy/clawdbot-curtis.env.template` → `/opt/clawdbot-curtis.env`
- `deploy/oauth2-proxy.cfg.template` → `/etc/oauth2-proxy.cfg`
- `deploy/oauth2-proxy-curtis.cfg.template` → `/etc/oauth2-proxy-curtis.cfg`
- `deploy/clawdbot.json.template` → `/home/clawdbot/.clawdbot/clawdbot.json`
- `deploy/clawdbot-curtis.json.template` → `/home/clawdbot-curtis/.clawdbot/clawdbot.json`

### What's NOT backed up (by design)
- `uploads/` — temporary files, disposable
- Actual secret values — must be re-entered manually from a secure source
- FileBrowser databases — recreated on setup (restore.sh handles this)

## Workspace Backups
Daily automated backups of both workspaces (`/home/clawdbot/clawd/` and `/home/clawdbot-curtis/clawd/`).

- **Script:** `/opt/backup-workspaces.sh`
- **Schedule:** Daily at 3am UTC via `workspace-backup.timer`
- **Storage:** `/var/backups/workspaces/` (7-day rotation)
- **Format:** `seth-YYYY-MM-DD.tar.gz`, `curtis-YYYY-MM-DD.tar.gz`
- **Manual run:** `systemctl start workspace-backup.service`
- **Offsite:** Script has rclone sync stub — uncomment after configuring `rclone` with DO Spaces or S3

## Artifacts / Canvas
ClawdBot creates interactive HTML artifacts (reports, dashboards, presentations) in the `canvas/` directory of each workspace.

- **Gallery:** `https://<subdomain>/canvas/` — lists all artifacts with iframe previews
- **Direct link:** `https://<subdomain>/canvas/<filename>.html`
- **Local instance:** `http://127.0.0.1:18789/__clawdbot__/canvas/<filename>.html`
- Gallery page: `/opt/canvas-gallery.html` (backed up as `deploy/canvas-gallery.html`)
- AGENTS.md in each workspace instructs ClawdBot to create self-contained HTML with CDN libraries (Chart.js, Mermaid, etc.)

## Browser Control (Playwright)
Both droplet instances have Playwright Chromium configured for headless browsing.

- **Config:** `browser.enabled: true`, `browser.headless: true`, `browser.noSandbox: true`
- **Executable:** Per-user Playwright cache at `~/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome`
- **System deps:** xvfb, fonts installed via `npx playwright install-deps chromium`
- **CDP port:** 18800 (default)

## File Types Allowed
.png, .jpg, .jpeg, .gif, .webp, .svg, .pdf, .txt, .md, .csv, .json, .mp4, .mp3, .wav, .webm

## Max Upload Size
25 MB
