// Electron shell for Hexic HD: serves the Ruffle web bundle from a privileged
// app://hexic/ origin (stable, so localStorage saves persist) and hosts it in
// a single 16:9 window.
const { app, BrowserWindow, Menu, protocol, ipcMain } = require("electron");
const fs = require("fs");
const os = require("os");
const path = require("path");

const SCHEME = "app";
const HOST = "hexic";
const ORIGIN = `${SCHEME}://${HOST}`;
const START_URL = `${ORIGIN}/index.html`;
const WIDTH = 1280;
const HEIGHT = 720;
// Debug logging and the test-script hook only exist in unpackaged dev runs.
const DEBUG = !app.isPackaged && process.env.HEXIC_DEBUG === "1";
// Everything is local; Ruffle needs inline config script + WebAssembly compile.
const CSP = [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "media-src 'self' data: blob:",
    "font-src 'self' data: blob:",
    "connect-src 'self' data: blob:",
    "worker-src 'self' blob:",
].join("; ");

const WWW = process.env.HEXIC_WWW && !app.isPackaged
    ? path.resolve(process.env.HEXIC_WWW)
    : app.isPackaged
    ? path.join(process.resourcesPath, "www")
    : path.join(__dirname, "..", "..", "build", "www");

const MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json",
    ".wasm": "application/wasm",
    ".swf": "application/x-shockwave-flash",
    ".ogg": "audio/ogg",
    ".mp3": "audio/mpeg",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".xml": "application/xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".txt": "text/plain; charset=utf-8",
};

function log(...args) {
    if (DEBUG) console.log("[hexic]", ...args);
}

// Keep dev and test runs from reading or overwriting the installed game's saves.
if (!app.isPackaged) app.setPath("userData", app.getPath("userData") + " Dev");

protocol.registerSchemesAsPrivileged([{
    scheme: SCHEME,
    privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true, corsEnabled: true },
}]);

function gamerTag() {
    let name = "";
    try {
        name = os.userInfo().username || "";
    } catch (_) { /* fall through */ }
    name = name || process.env.USER || process.env.USERNAME || "Player";
    // Xbox gamertags were at most 15 characters; the leaderboard is laid out for that.
    const chars = Array.from(name.split(/[\s._@-]+/)[0] || "Player").slice(0, 15);
    return chars[0].toUpperCase() + chars.slice(1).join("");
}

// Byte-range support so <audio> gets a finite duration and can seek; a plain
// net.fetch of the file ignores the request's Range header.
async function rangeResponse(request, file, size, headers) {
    headers.set("Accept-Ranges", "bytes");
    const match = /^bytes=(\d*)-(\d*)$/.exec(request.headers.get("Range") || "");
    let start = 0;
    let end = size - 1;
    let status = 200;
    if (match && (match[1] || match[2])) {
        if (match[1]) {
            start = Number(match[1]);
            if (match[2]) end = Math.min(Number(match[2]), size - 1);
        } else {
            start = Math.max(0, size - Number(match[2]));
        }
        if (start > end || start >= size) {
            headers.set("Content-Range", `bytes */${size}`);
            return new Response(null, { status: 416, headers });
        }
        status = 206;
        headers.set("Content-Range", `bytes ${start}-${end}/${size}`);
    }
    headers.set("Content-Length", String(end - start + 1));
    if (request.method === "HEAD") return new Response(null, { status, headers });
    // Read the bytes up front rather than streaming: the largest file is the
    // 14 MB WebAssembly module, and a stream left open by a cancelled request
    // (e.g. a reload mid-load) broke the next load of that module.
    const body = Buffer.alloc(end - start + 1);
    const handle = await fs.promises.open(file, "r");
    try {
        await handle.read(body, 0, body.length, start);
    } finally {
        await handle.close();
    }
    return new Response(body, { status, headers });
}

async function serve(request) {
    const url = new URL(request.url);
    if (url.host !== HOST) return new Response("Not found", { status: 404 });
    let rel;
    try {
        rel = decodeURIComponent(url.pathname);
    } catch (_) {
        return new Response("Bad request", { status: 400 });
    }
    if (rel === "/" || rel === "") rel = "/index.html";
    const root = path.resolve(WWW);
    const file = path.resolve(root, "." + rel);
    // Path traversal guard: the resolved file must stay inside www/.
    if (file !== root && !file.startsWith(root + path.sep)) {
        log("blocked traversal", request.url);
        return new Response("Forbidden", { status: 403 });
    }
    let stat;
    try {
        stat = await fs.promises.stat(file);
        if (!stat.isFile()) return new Response("Not found", { status: 404 });
    } catch (_) {
        log("404", rel);
        return new Response("Not found", { status: 404 });
    }
    const headers = new Headers({
        "Content-Type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream",
        "Cache-Control": "no-cache",
        "Content-Security-Policy": CSP,
    });
    return rangeResponse(request, file, stat.size, headers);
}

function toggleFullScreen(win) {
    if (win && !win.isDestroyed()) win.setFullScreen(!win.isFullScreen());
}

function buildMenu() {
    if (process.platform !== "darwin") {
        Menu.setApplicationMenu(null);
        return;
    }
    Menu.setApplicationMenu(Menu.buildFromTemplate([
        { role: "appMenu" },
        {
            label: "View",
            submenu: [{ role: "togglefullscreen" }],
        },
        { role: "windowMenu" },
    ]));
}

function focusPlayer(win) {
    // Give the Ruffle element keyboard focus so keys work without a click.
    win.webContents.focus();
    return win.webContents.executeJavaScript(`(() => {
        const p = document.querySelector("ruffle-player, ruffle-object");
        if (!p) return false;
        if (!p.hasAttribute("tabindex")) p.setAttribute("tabindex", "0");
        // Blur first so Ruffle sees a fresh focusin even if the element
        // already had focus before its listeners were attached.
        p.blur();
        p.focus({ preventScroll: true });
        return document.activeElement === p;
    })()`).catch(() => false);
}

function createWindow() {
    const win = new BrowserWindow({
        width: WIDTH,
        height: HEIGHT,
        useContentSize: true,
        minWidth: 640,
        minHeight: 360,
        resizable: true,
        backgroundColor: "#000000",
        title: "Hexic HD",
        show: false,
        autoHideMenuBar: true,
        webPreferences: {
            preload: path.join(__dirname, "preload.js"),
            contextIsolation: true,
            nodeIntegration: false,
            sandbox: true,
            autoplayPolicy: "no-user-gesture-required",
            additionalArguments: [`--hexic-gamertag=${gamerTag()}`],
            spellcheck: false,
        },
    });
    win.setAspectRatio(16 / 9);
    win.setMenuBarVisibility(process.platform === "darwin");

    const wc = win.webContents;

    wc.on("page-title-updated", (e) => e.preventDefault());

    // F11 and Alt+Enter toggle fullscreen on every platform.
    // Both halves of the shortcut are swallowed so the game never sees a
    // stray Enter (its A button); holding the keys doesn't flicker fullscreen.
    let swallowing = null;
    wc.on("before-input-event", (event, input) => {
        const altEnter = input.alt && (input.key === "Enter" || input.code === "Enter" || input.code === "NumpadEnter");
        const shortcut = input.key === "F11" || altEnter;
        if (input.type === "keyUp") {
            if (swallowing && (shortcut || input.code === swallowing)) {
                event.preventDefault();
                swallowing = null;
            }
            return;
        }
        if (input.type !== "keyDown" || !shortcut) return;
        event.preventDefault();
        swallowing = input.code;
        if (!input.isAutoRepeat) toggleFullScreen(win);
    });

    // Never navigate away from the game or open new windows.
    wc.on("will-navigate", (event, url) => {
        if (!url.startsWith(ORIGIN + "/")) {
            log("blocked navigation", url);
            event.preventDefault();
        }
    });
    wc.on("will-redirect", (event, url) => {
        if (!url.startsWith(ORIGIN + "/")) event.preventDefault();
    });
    wc.setWindowOpenHandler(({ url }) => {
        log("blocked window.open", url);
        return { action: "deny" };
    });

    if (DEBUG) {
        wc.on("console-message", (event) => {
            const { level, message, sourceId, lineNumber } = event;
            console.log(`[renderer:${level}] ${message} (${sourceId}:${lineNumber})`);
        });
        wc.on("did-fail-load", (_e, code, desc, url) => console.log("[hexic] did-fail-load", code, desc, url));
        wc.on("render-process-gone", (_e, details) => console.log("[hexic] render-process-gone", details));
    }

    win.once("ready-to-show", () => {
        // HEXIC_SHOW_INACTIVE (debug only) keeps automated test runs from
        // taking keyboard focus away from whatever the user is doing.
        if (DEBUG && process.env.HEXIC_SHOW_INACTIVE === "1") {
            win.showInactive();
            return;
        }
        win.show();
        win.focus();
    });

    wc.on("did-finish-load", async () => {
        log("did-finish-load", wc.getURL());
        // The player element is created by host.js; retry briefly until it exists.
        for (let i = 0; i < 50; i++) {
            if (await focusPlayer(win)) {
                log("ruffle-player focused");
                return;
            }
            await new Promise((r) => setTimeout(r, 100));
        }
        log("could not focus ruffle-player");
    });
    win.on("focus", () => focusPlayer(win));

    win.loadURL(START_URL);
    return win;
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
    app.quit();
} else {
    app.on("second-instance", () => {
        const [win] = BrowserWindow.getAllWindows();
        if (win) {
            if (win.isMinimized()) win.restore();
            if (!win.isVisible()) win.show();
            if (process.platform === "darwin") app.focus({ steal: true });
            win.focus();
        }
    });

    ipcMain.on("hexic:quit", () => app.quit());

    app.on("web-contents-created", (_e, contents) => {
        contents.on("will-attach-webview", (event) => event.preventDefault());
    });

    app.whenReady().then(() => {
        log("serving", WWW, "userData", app.getPath("userData"));
        protocol.handle(SCHEME, serve);
        buildMenu();
        const win = createWindow();
        if (DEBUG) global.hexicWindow = win;
        if (DEBUG && process.env.HEXIC_TEST_SCRIPT) {
            // Dev-only hook for automated verification; never set in normal use.
            require(path.resolve(process.env.HEXIC_TEST_SCRIPT))(win, { app, log });
        }
    });

    // It's a game: quit when the window closes, on macOS too.
    app.on("window-all-closed", () => app.quit());
}
