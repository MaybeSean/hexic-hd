// electron-builder afterPack hook: put the app icon into Hexic HD.exe.
// electron-builder's own resource edit leaves Electron's default icon when
// building on macOS, so the icon group is replaced here with resedit (pure
// JavaScript, no Wine). Runs before the installer and portable targets are
// made, so all Windows builds get it.
const fs = require("fs");
const path = require("path");
const PE = require("pe-library");
const ResEdit = require("resedit");

module.exports = async function (context) {
    if (context.electronPlatformName !== "win32") return;
    const exePath = path.join(context.appOutDir, `${context.packager.appInfo.productFilename}.exe`);
    const icon = ResEdit.Data.IconFile.from(fs.readFileSync(path.join(__dirname, "..", "build", "icon.ico")));
    const exe = PE.NtExecutable.from(fs.readFileSync(exePath), { ignoreCert: true });
    const resources = PE.NtExecutableResource.from(exe);
    const groups = ResEdit.Resource.IconGroupEntry.fromEntries(resources.entries);
    if (groups.length === 0) throw new Error(`no icon group in ${exePath}`);
    for (const group of groups) {
        ResEdit.Resource.IconGroupEntry.replaceIconsForResource(
            resources.entries, group.id, group.lang, icon.icons.map((item) => item.data));
    }
    resources.outputResource(exe);
    fs.writeFileSync(exePath, Buffer.from(exe.generate()));
    console.log(`  • set app icon  file=${exePath}`);
};
