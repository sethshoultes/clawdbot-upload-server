# ClawdBot Upload Server

## Project Overview
A file upload server and floating UI button for ClawdBot's Control UI. Users can upload files (images, docs, media) via a paperclip button or drag-and-drop, and the file path/URL gets inserted into the chat textarea for ClawdBot to process.

## GitHub Repo
- **Repo:** https://github.com/sethshoultes/clawdbot-upload-server
- **Branch:** `master`
- **CI/CD:** GitHub Actions deploys to DO droplet on push to `master`
- **Secrets required:** `DO_HOST`, `DO_USER`, `DO_SSH_KEY`

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

### DigitalOcean Droplet (production, team access)
- Domain: `64-23-141-85.nip.io` (HTTPS via Caddy auto-TLS)
- `PUBLIC_BASE_URL`: `https://64-23-141-85.nip.io` (set in systemd service)
- Upload server cloned from this repo to `/home/clawdbot/upload-server/`
- Script tag uses relative path: `<script src="/upload-button.js" defer>`

#### Droplet Services (systemd)
| Service | Description | Port |
|---|---|---|
| `clawdbot.service` | Main ClawdBot gateway | 18789 |
| `clawdbot-upload.service` | Upload server | 3456 |
| `oauth2-proxy.service` | Google OAuth (@caseproof.com) | 4180 |
| `caddy.service` | Reverse proxy, HTTPS | 443 |

#### Caddy Routes
| Route | Target |
|---|---|
| `/upload` | localhost:3456 (upload endpoint) |
| `/upload-button.js` | localhost:3456 (injection script) |
| `/files/*` | localhost:3456 (serve uploaded files) |
| `/videos/*` | Static files (Remotion video output) |
| `/*` (default) | localhost:4180 (oauth2-proxy → ClawdBot) |

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

1. Install ClawdBot, Caddy, oauth2-proxy, Docker on a fresh droplet
2. Clone this repo to `/home/clawdbot/upload-server/`
3. Run `sudo bash deploy/restore.sh`
4. Fill in secrets in the template files (API keys, OAuth secrets, tokens)
5. Restart services

### What's backed up
**Committed as-is (no secrets):**
- `deploy/Caddyfile` → `/etc/caddy/Caddyfile`
- `deploy/clawdbot.service` → `/etc/systemd/system/clawdbot.service`
- `deploy/clawdbot-upload.service` → `/etc/systemd/system/clawdbot-upload.service`
- `deploy/control-ui-index.html` → `/opt/clawdbot/dist/control-ui/index.html`

**Templates with `<PLACEHOLDER>` values (fill in secrets after restore):**
- `deploy/clawdbot.env.template` → `/opt/clawdbot.env`
- `deploy/oauth2-proxy.cfg.template` → `/etc/oauth2-proxy.cfg`
- `deploy/clawdbot.json.template` → `/home/clawdbot/.clawdbot/clawdbot.json`

### What's NOT backed up (by design)
- `uploads/` — temporary files, disposable
- Actual secret values — must be re-entered manually from a secure source

## File Types Allowed
.png, .jpg, .jpeg, .gif, .webp, .svg, .pdf, .txt, .md, .csv, .json, .mp4, .mp3, .wav, .webm

## Max Upload Size
25 MB
