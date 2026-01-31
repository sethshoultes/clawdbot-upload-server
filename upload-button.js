(function () {
  "use strict";

  // Auto-detect: use absolute URL on localhost (cross-origin), relative on production
  const UPLOAD_URL = location.hostname === "127.0.0.1" || location.hostname === "localhost"
    ? "http://127.0.0.1:3456/upload"
    : "/upload";

  // ── Find the chat textarea ────────────────────────────────────────
  function findTextarea() {
    // Content is in light DOM inside clawdbot-app
    var ta = document.querySelector("clawdbot-app textarea");
    if (ta) return ta;
    // Fallback: any textarea on the page
    ta = document.querySelector("textarea");
    if (ta) return ta;
    // Last resort: walk open shadow roots
    var app = document.querySelector("clawdbot-app");
    if (app && app.shadowRoot) {
      ta = app.shadowRoot.querySelector("textarea");
      if (ta) return ta;
    }
    return null;
  }

  // ── Insert text into the textarea ────────────────────────────────
  function insertIntoChat(text) {
    const ta = findTextarea();
    if (!ta) {
      console.warn("[upload] textarea not found in shadow DOM");
      alert("Could not find the chat input. Try refreshing the page.");
      return;
    }
    const before = ta.value;
    const sep = before && !before.endsWith("\n") ? "\n" : "";
    const nativeSet = Object.getOwnPropertyDescriptor(
      HTMLTextAreaElement.prototype, "value"
    ).set;
    nativeSet.call(ta, before + sep + text);
    ta.dispatchEvent(new Event("input", { bubbles: true }));
    ta.focus();
  }

  // ── Upload a file ────────────────────────────────────────────────
  async function uploadFile(file) {
    overlay.style.display = "flex";
    statusText.textContent = "Uploading " + file.name + "...";

    try {
      const resp = await fetch(UPLOAD_URL, {
        method: "POST",
        headers: { "X-Filename": file.name },
        body: file,
      });
      const data = await resp.json();
      if (!resp.ok) throw new Error(data.error || "upload failed");

      statusText.textContent = "Inserted into chat!";
      insertIntoChat(data.url);
      setTimeout(function () { overlay.style.display = "none"; }, 800);
    } catch (err) {
      statusText.textContent = "Error: " + err.message;
      setTimeout(function () { overlay.style.display = "none"; }, 2500);
    }
  }

  // ── Build SVG icon with safe DOM methods ─────────────────────────
  function createPaperclipIcon() {
    var ns = "http://www.w3.org/2000/svg";
    var svg = document.createElementNS(ns, "svg");
    svg.setAttribute("width", "22");
    svg.setAttribute("height", "22");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("fill", "none");
    svg.setAttribute("stroke", "currentColor");
    svg.setAttribute("stroke-width", "2");
    svg.setAttribute("stroke-linecap", "round");
    svg.setAttribute("stroke-linejoin", "round");
    var path = document.createElementNS(ns, "path");
    path.setAttribute("d", "M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48");
    svg.appendChild(path);
    return svg;
  }

  // ── Build the upload button ──────────────────────────────────────
  var btn = document.createElement("button");
  btn.id = "clawdbot-upload-btn";
  btn.appendChild(createPaperclipIcon());
  btn.title = "Upload file to chat";
  Object.assign(btn.style, {
    width: "40px",
    height: "40px",
    borderRadius: "50%",
    border: "none",
    background: "#6C63FF",
    color: "#fff",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: "0",
    boxShadow: "0 2px 8px rgba(108,99,255,0.4)",
    transition: "transform 0.15s, box-shadow 0.15s",
  });
  btn.addEventListener("mouseenter", function () {
    btn.style.transform = "scale(1.1)";
    btn.style.boxShadow = "0 4px 12px rgba(108,99,255,0.5)";
  });
  btn.addEventListener("mouseleave", function () {
    btn.style.transform = "scale(1)";
    btn.style.boxShadow = "0 2px 8px rgba(108,99,255,0.4)";
  });

  // Hidden file input
  var fileInput = document.createElement("input");
  fileInput.type = "file";
  fileInput.accept = "image/*,.pdf,.txt,.md,.csv,.json,.mp4,.mp3,.wav,.webm";
  fileInput.style.display = "none";
  fileInput.addEventListener("change", function () {
    if (fileInput.files.length > 0) uploadFile(fileInput.files[0]);
    fileInput.value = "";
  });

  btn.addEventListener("click", function () { fileInput.click(); });

  // ── Status overlay ───────────────────────────────────────────────
  var overlay = document.createElement("div");
  Object.assign(overlay.style, {
    display: "none",
    position: "fixed",
    inset: "0",
    zIndex: "100000",
    background: "rgba(0,0,0,0.6)",
    alignItems: "center",
    justifyContent: "center",
  });

  var card = document.createElement("div");
  Object.assign(card.style, {
    background: "#1a1a2e",
    color: "#fff",
    padding: "32px 48px",
    borderRadius: "16px",
    textAlign: "center",
    fontSize: "18px",
    fontFamily: "system-ui, sans-serif",
    boxShadow: "0 8px 32px rgba(0,0,0,0.5)",
  });

  var statusText = document.createElement("p");
  statusText.textContent = "Uploading...";
  card.appendChild(statusText);
  overlay.appendChild(card);

  // ── Drag-and-drop support ────────────────────────────────────────
  var dragCounter = 0;
  var dropZone = document.createElement("div");
  Object.assign(dropZone.style, {
    display: "none",
    position: "fixed",
    inset: "0",
    zIndex: "100001",
    background: "rgba(108,99,255,0.15)",
    border: "4px dashed #6C63FF",
    alignItems: "center",
    justifyContent: "center",
    pointerEvents: "none",
  });
  var dropLabel = document.createElement("div");
  Object.assign(dropLabel.style, {
    fontSize: "28px",
    fontWeight: "700",
    color: "#6C63FF",
    fontFamily: "system-ui, sans-serif",
    background: "rgba(0,0,0,0.7)",
    padding: "24px 48px",
    borderRadius: "16px",
  });
  dropLabel.textContent = "Drop file to upload";
  dropZone.appendChild(dropLabel);

  document.addEventListener("dragenter", function (e) {
    e.preventDefault();
    dragCounter++;
    if (dragCounter === 1) dropZone.style.display = "flex";
  });
  document.addEventListener("dragleave", function (e) {
    e.preventDefault();
    dragCounter--;
    if (dragCounter <= 0) { dragCounter = 0; dropZone.style.display = "none"; }
  });
  document.addEventListener("dragover", function (e) { e.preventDefault(); });
  document.addEventListener("drop", function (e) {
    e.preventDefault();
    dragCounter = 0;
    dropZone.style.display = "none";
    var files = e.dataTransfer && e.dataTransfer.files;
    if (files && files.length > 0) uploadFile(files[0]);
  });

  // ── Mount: insert into .chat-compose grid, before the label ─────
  function mountButton() {
    // Already mounted and still in DOM — nothing to do
    if (btn.parentElement && document.body.contains(btn)) return;

    var ta = findTextarea();
    if (!ta) return;

    // The structure is: div.chat-compose > label.chat-compose__field > textarea
    var compose = ta.closest(".chat-compose");
    var field = ta.closest(".chat-compose__field");

    if (compose && field) {
      // Add a column for the button in the grid
      compose.style.gridTemplateColumns = "auto 1fr auto";
      compose.style.alignItems = "end";
      compose.insertBefore(btn, field);
      // Align button to bottom of the row (next to textarea baseline)
      btn.style.marginBottom = "4px";
    } else {
      // Fallback: fixed position
      Object.assign(btn.style, {
        position: "fixed",
        bottom: "90px",
        right: "24px",
        zIndex: "99999",
      });
      document.body.appendChild(btn);
    }

    if (!document.body.contains(fileInput)) document.body.appendChild(fileInput);
    if (!document.body.contains(overlay)) document.body.appendChild(overlay);
    if (!document.body.contains(dropZone)) document.body.appendChild(dropZone);
    console.log("[clawdbot-upload] Upload button injected next to textarea");
  }

  // Re-mount after SPA navigation destroys the button
  setInterval(mountButton, 1000);
  mountButton();
})();
