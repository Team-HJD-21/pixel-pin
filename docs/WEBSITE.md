# Pixel Pin website

- Production: https://pixelpin.teamhjd.com/
- Release notes: https://pixelpin.teamhjd.com/changelog/
- Hosting: GitHub Pages, GitHub Actions source
- Workflow: `.github/workflows/pages.yml`

## Domain

The repository's Pages custom domain is `pixelpin.teamhjd.com`.

| Type | Name | Target | Proxy |
| --- | --- | --- | --- |
| CNAME | `pixelpin` | `team-hjd-21.github.io` | DNS only |

The custom domain is configured in GitHub Pages settings; a `CNAME` file is not required for the custom Actions deployment. HTTPS enforcement is enabled after GitHub issues a certificate. Keep the existing apex, mail, and other subdomain records unchanged.

## Build and preview

Node.js 22 or later; no package installation is required.

```powershell
node scripts/build-site.mjs
node scripts/check-site.mjs
node scripts/test-site.mjs
node scripts/preview-site.mjs
```

Open `http://127.0.0.1:4173/`. Generated files are written to the ignored `.pages/` directory. Only this directory is uploaded to Pages; app source and binaries are not part of the website artifact.

The build fetches published, stable GitHub releases and generates the download link, version history, and release notes. Visitors receive static HTML and do not call the GitHub API. Source HTML in release notes is escaped before rendering. Draft and prerelease versions are excluded.

Publishing, editing, deleting, or unpublishing a release rebuilds the site. A relevant push to `main` also rebuilds it. A manual run can be started from Actions → Deploy Pixel Pin website if needed.

In Actions, `GITHUB_TOKEN` is passed only to the build process. No token is written into source or generated pages. `BASE_PATH` and `SITE_URL` come from the Pages configuration so paths also work with a repository URL.

Screenshots are sample-data renders of the app interface, not a capture of a user's desktop. The browser color playground uses sample colors; screen picking requires the desktop app.
