# Running this fork as the local Komga server on Windows

This fork is deployed as a plain Spring Boot jar (no tray app, no MSIX). The server
starts at logon through a per-user scheduled task named `Komga`, listens on
<http://localhost:25600>, and keeps its data in `%LOCALAPPDATA%\Komga` (the same
folder the official tray app uses).

## Prerequisites

- Git
- Eclipse Temurin JDK 21 (installed under `C:\Program Files\Eclipse Adoptium`)
- Node.js (the two web UIs declare Node 22 and 24 in their `.nvmrc`; current LTS works)

All three can be installed with `winget install Git.Git EclipseAdoptium.Temurin.21.JDK OpenJS.NodeJS.LTS`.

## Scripts

| Script | When |
| --- | --- |
| `build-and-deploy.ps1` | After every code change. Builds `komga-webui`, `next-ui` and the jar, copies the jar to `%LOCALAPPDATA%\Programs\Komga-navigator\komga.jar`, restarts the `Komga` task. `-SkipUi` reuses the existing UI bundles, `-SkipDeploy` only builds. |
| `install-service.ps1` | Once per machine. Registers the `Komga` scheduled task (javaw, hidden, restarts on failure) and starts it. Re-run to change the command line. |
| `migrate-data-from-tray.ps1` | Once, when replacing the official tray app. Copies its data out of the MSIX package folder (which Windows deletes on uninstall) into `%LOCALAPPDATA%\Komga`, with a dated safety copy next to it. |

Run them from a normal PowerShell window in the repo root, for example:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\build-and-deploy.ps1
```

## Notes

- The scheduled task command line must not contain quotes or spaces in paths; `install-service.ps1` refuses paths with whitespace.
- `next-ui` needed a small Vite plugin in `vite.config.mts` to build on Windows: `vite-plugin-dir2json` emits import paths with backslashes, and `\src\i18n\uk.json` is read as an invalid `\u` escape.
- The `komga-webui` build runs its TypeScript type-checker in a worker that can run out of memory; the bundle is still emitted. `build-and-deploy.ps1` sets `NODE_OPTIONS=--max-old-space-size=4096`.
- To stop or start the server by hand: `Stop-ScheduledTask -TaskName Komga` / `Start-ScheduledTask -TaskName Komga`. Logs are in `%LOCALAPPDATA%\Komga\logs\komga.log`.
