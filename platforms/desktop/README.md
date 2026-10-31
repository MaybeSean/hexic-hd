# Hexic HD desktop app

The Electron app for macOS and Windows. It serves the Ruffle web bundle
(`../../build/www`, made by `tools/build_web.sh`) from a private `app://hexic/`
origin, so saves in `localStorage` persist between launches.

Building, controls and save locations are covered in the [main README](../../README.md).

## Development

```sh
npm ci
npm start           # run against ../../build/www
npm run dist:mac    # ../../dist/macos
npm run dist:win    # ../../dist/windows
```

- `scripts/win-icon.js` writes the app icon into `Hexic HD.exe` after packaging.
  electron-builder's own resource edit doesn't take effect when building on macOS.
- Development runs keep their save data in a separate `Hexic HD Dev` folder.
- `HEXIC_DEBUG=1` logs renderer console output to stdout. It only works when
  unpackaged.
