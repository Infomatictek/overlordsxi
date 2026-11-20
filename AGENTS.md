# SoulspireXI Workspace Rules

## Repository Sync & Push Requirement (Mandatory)

- **Source of Truth**: All custom SoulspireXI modules (`modules/custom/**`, `modules/init.append.txt`), engine patches (`patches/*.patch`), and setup scripts (`scripts/setup-local-server.ps1`) are tracked in `C:\overlordsxi` (remote `origin`: `https://github.com/Infomatictek/overlordsxi.git`), **not** in `c:\dev\server` (which tracks upstream `landsandboat/server`).
- **Always Push to `C:\overlordsxi` First**:
  1. Whenever creating or modifying custom Lua modules, C++ modules, SQL files, module initialization lists, or engine patches, always ensure the changes are synced into `C:\overlordsxi` (and mirrored in `c:\dev\server` for local testing).
  2. If a new custom module file is created, register it in both `C:\overlordsxi\modules\init.append.txt` and `c:\dev\server\modules\init.txt`.
  3. If core LandSandBoat C++/Lua files in `c:\dev\server` are modified, either package the change as a numbered patch in `C:\overlordsxi\patches/` or implement the hook in `C:\overlordsxi\modules\custom/`.
  4. **Before finishing any implementation turn**, stage, commit, and `git push origin HEAD` in `C:\overlordsxi` so the user can immediately `git pull` the changes down.
