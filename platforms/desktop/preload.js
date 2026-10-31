// Exposes the small host API that host.js looks for as window.hexicHost.
const { contextBridge, ipcRenderer } = require("electron");

const arg = process.argv.find((a) => a.startsWith("--hexic-gamertag="));
const gamerTag = (arg && arg.slice("--hexic-gamertag=".length)) || "Player";

contextBridge.exposeInMainWorld("hexicHost", {
    gamerTag,
    quit: () => ipcRenderer.send("hexic:quit"),
});
