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

## Option 3: 100% Zero-Touch SWAG Proxy (Auto-Updates BOTH Data AND UI Forever)

If you never want to copy `index.html`, `app.js`, or `styles.css` to SWAG again—even when the Wiki UI itself gets new features—you can have SWAG proxy the entire `site/` folder directly from GitHub (works for both **Public** and **Private** repos, while setting proper MIME types since `raw.githubusercontent.com` returns `text/plain`):

```nginx
# Inside your server { ... } block in SWAG:
location / {
    proxy_ssl_server_name on;
    proxy_set_header Host raw.githubusercontent.com;
    # If your repo is Private, uncomment and add a Fine-Grained Token with ONLY "Contents: Read-only":
    # proxy_set_header Authorization "Bearer github_pat_YOUR_READ_ONLY_TOKEN_HERE";
    proxy_hide_header Set-Cookie;
    proxy_hide_header Content-Type;
    proxy_hide_header X-Content-Type-Options;
    proxy_ignore_headers Set-Cookie;

    rewrite ^/$ /index.html break;
    proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site/;

    location ~* \.html$ { add_header Content-Type "text/html; charset=utf-8"; proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site$uri; }
    location ~* \.css$  { add_header Content-Type "text/css; charset=utf-8";  proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site$uri; }
    location ~* \.js$   { add_header Content-Type "application/javascript; charset=utf-8"; proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site$uri; }
    location ~* \.json$ { add_header Content-Type "application/json; charset=utf-8"; proxy_pass https://raw.githubusercontent.com/Infomatictek/overlordsxi/main/site$uri; }
}
```

With Option 3, **nothing lives on SWAG at all**—every push to `Infomatictek/overlordsxi` updates both the wiki data (`data.json`) and any future UI updates (`index.html`, `app.js`, `styles.css`) automatically.

