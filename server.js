import { createServer } from "node:http";
import { createWriteStream, existsSync, mkdirSync, statSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { join, extname, basename } from "node:path";
import { randomBytes } from "node:crypto";
import { pipeline } from "node:stream/promises";

const PORT = 3456;
const UPLOAD_DIR = new URL("./uploads/", import.meta.url).pathname;
const SCRIPT_PATH = new URL("./upload-button.js", import.meta.url).pathname;

// When PUBLIC_BASE_URL is set, return HTTPS URLs (for DO droplet where ClawdBot
// runs in Docker and can't read local files). When unset, return local file paths.
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || "";

// Allowed file extensions
const ALLOWED_EXT = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg",
  ".pdf", ".txt", ".md", ".csv", ".json",
  ".mp4", ".mp3", ".wav", ".webm",
]);

const MAX_SIZE = 25 * 1024 * 1024; // 25 MB

if (!existsSync(UPLOAD_DIR)) mkdirSync(UPLOAD_DIR, { recursive: true });

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-Filename");
}

function json(res, code, data) {
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
}

function serveFile(res, filePath, contentType) {
  readFile(filePath).then((buf) => {
    res.writeHead(200, { "Content-Type": contentType });
    res.end(buf);
  }).catch(() => {
    json(res, 404, { error: "not found" });
  });
}

const MIME = {
  ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
  ".gif": "image/gif", ".webp": "image/webp", ".svg": "image/svg+xml",
  ".pdf": "application/pdf", ".txt": "text/plain", ".md": "text/plain",
  ".csv": "text/csv", ".json": "application/json",
  ".mp4": "video/mp4", ".mp3": "audio/mpeg", ".wav": "audio/wav",
  ".webm": "video/webm", ".js": "application/javascript",
};

const server = createServer(async (req, res) => {
  cors(res);
  const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    return res.end();
  }

  // Serve the injection script
  if (req.method === "GET" && url.pathname === "/upload-button.js") {
    return serveFile(res, SCRIPT_PATH, "application/javascript");
  }

  // Serve uploaded files
  if (req.method === "GET" && url.pathname.startsWith("/files/")) {
    const filename = basename(url.pathname);
    const filePath = join(UPLOAD_DIR, filename);
    const ext = extname(filename).toLowerCase();
    if (!existsSync(filePath)) return json(res, 404, { error: "not found" });
    return serveFile(res, filePath, MIME[ext] ?? "application/octet-stream");
  }

  // Handle upload — raw binary POST with X-Filename header
  if (req.method === "POST" && url.pathname === "/upload") {
    const origName = req.headers["x-filename"] ?? "file";
    const ext = extname(origName).toLowerCase();

    if (!ALLOWED_EXT.has(ext)) {
      return json(res, 400, { error: `file type ${ext} not allowed` });
    }

    const contentLength = parseInt(req.headers["content-length"] ?? "0", 10);
    if (contentLength > MAX_SIZE) {
      return json(res, 413, { error: "file too large (25 MB max)" });
    }

    const id = randomBytes(8).toString("hex");
    const safeName = `${id}${ext}`;
    const dest = join(UPLOAD_DIR, safeName);

    try {
      const ws = createWriteStream(dest);
      await pipeline(req, ws);
      const fileRef = PUBLIC_BASE_URL ? `${PUBLIC_BASE_URL}/files/${safeName}` : dest;
      console.log(`uploaded: ${origName} → ${fileRef}`);
      return json(res, 200, { url: fileRef, filename: safeName, path: fileRef });
    } catch (err) {
      console.error("upload error:", err);
      return json(res, 500, { error: "upload failed" });
    }
  }

  json(res, 404, { error: "not found" });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Upload server running on http://127.0.0.1:${PORT}`);
  console.log(`Upload dir: ${UPLOAD_DIR}`);
  console.log(`Injection script: http://127.0.0.1:${PORT}/upload-button.js`);
});
