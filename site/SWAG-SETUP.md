# OverlordsXI Server Wiki — SWAG Deployment Guide

The `site/` folder is a **zero-maintenance static web encyclopedia** for OverlordsXI.

It contains:
- `index.html` — The main Wiki shell
- `styles.css` — Dark FFXI / Crystal-themed responsive stylesheet
- `app.js` — Client-side Wiki router, global search (`/`), Job Crystal guide renderer, 219-Weaponskill Talent Tree explorer, and live GitHub sync engine
- `data.json` & `data.js` — Auto-generated structured wiki database parsed directly from `modules/custom/lua/*.lua`, `modules/custom/sql/*.sql`, `modules/custom/commands/*.lua`, and `patches/*.patch` via `scripts/generate-site-data.py` (and kept up-to-date automatically on every push by `.github/workflows/update-wiki.yml`).

---

## Option 1: Drop the Files into SWAG's `www` Folder (While Repo is Public)

Copy the contents of `site/` (`index.html`, `styles.css`, `app.js`, `data.json`, `data.js`) into your SWAG container's web root (e.g. `/config/www/overlordsxi/` or `/config/www/`).

Every time a player opens the page:
1. It immediately loads and renders the full wiki.
2. In the background, `app.js` fetches the latest `site/data.json` and commit history directly from `https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site/data.json` and `api.github.com`—so **you never have to update any files on your SWAG server** when you push new Lua specs, weaponskill talent trees, or patches to GitHub.

---

## Option 2: When You Make `Infomatictek/overlordsxi` Private Before Release

When you switch the GitHub repository to **Private**, `raw.githubusercontent.com` will require a read-only token header. To keep your token 100% hidden on the server side (so players never see it in browser DevTools) and still never have to update files on SWAG, add this tiny proxy block inside your SWAG nginx site config (`/config/nginx/site-confs/default.conf` or your subdomain `.conf`):

```nginx
# Inside your server { ... } block in SWAG:
location = /data.json {
    proxy_ssl_server_name on;
    proxy_set_header Host raw.githubusercontent.com;
    # Create a Fine-Grained GitHub Personal Access Token with ONLY "Contents: Read-only" on Infomatictek/overlordsxi
    proxy_set_header Authorization "Bearer github_pat_YOUR_READ_ONLY_TOKEN_HERE";
    proxy_hide_header Set-Cookie;
    proxy_ignore_headers Set-Cookie;

    # Optional: cache at SWAG for 2 minutes so 1000s of players hit SWAG cache instantly
    proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site/data.json;
}
```

With that 10-line block in SWAG:
1. Your `Infomatictek/overlordsxi` repo can be **100% Private**.
2. Every time you `git push` to `Infomatictek/overlordsxi`, the GitHub Action (`.github/workflows/update-wiki.yml`) automatically runs `scripts/generate-site-data.py` and updates `site/data.json` in the repo.
3. Your SWAG server proxies `/data.json` from the private repo using your read-only token—so **nothing on your SWAG server ever needs to be manually updated**.
