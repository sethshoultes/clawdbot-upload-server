# ClawdBot Upload Server

A lightweight Node.js file upload server that accepts file uploads and serves them back, used by ClawdBot's Control UI to attach files to chat messages.

## Quick Start

```bash
node server.js
```

The server starts on `http://127.0.0.1:3456`.

## Environment

The upload server has two deployment targets:

- **Local development** -- Runs on `localhost:3456` and returns local filesystem paths in upload responses. Files are stored in the `uploads/` directory relative to the server.
- **DigitalOcean production** -- Runs on a DO droplet at `64.23.141.85` as a systemd service (`clawdbot-upload`). In production the server returns HTTPS URLs so uploaded files are accessible over the internet.

## Deploy

Deployment is automated via GitHub Actions CI/CD. Every push to the `main` branch triggers a deploy that SSHs into the DigitalOcean droplet, pulls the latest code, and restarts the service.

The workflow lives at `.github/workflows/deploy.yml` and requires three repository secrets:

| Secret | Description |
|---|---|
| `DO_SSH_KEY` | Private SSH key authorized to access the droplet |
| `DO_HOST` | Droplet IP address (e.g. `64.23.141.85`) |
| `DO_USER` | SSH user on the droplet (e.g. `root`) |

To configure these, go to **Settings > Secrets and variables > Actions** in the GitHub repository and add each secret.

## Upload Button

The `upload-button.js` script is injected into ClawdBot's Control UI `index.html` via a `<script>` tag. It adds a paperclip button next to the chat textarea and supports both click-to-upload and drag-and-drop. Uploaded file paths/URLs are automatically inserted into the chat input.
