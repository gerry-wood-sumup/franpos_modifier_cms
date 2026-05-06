# franpos_auxiliary_dam

This repository is the **Digital Asset Management (DAM)** store for auxiliary media leveraged by the FranPOS POS, Kiosk, and other merchant and consumer-facing devices.

---

## Repository Structure

```
franpos_modifier_cms/
├── images/
│   └── modifiers/
│       └── toppings/
├── kiosk-carousel/
│   ├── live/
│   │   ├── global/
│   │   └── <CID>/      (6-digit numeric Company ID, e.g. 206100)
│   └── staging/
│       ├── global/
│       └── <CID>/
├── documents/
├── sounds/
├── videos/
└── miscellaneous/
```

### `images/`
Static image assets displayed across POS, Kiosk, and consumer-facing surfaces.

Organized by the modifier/menu category they belong to:

| Path | Browse | Description |
|------|--------|-------------|
| `images/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/images/) | Navigate all image asset folders |

**Accepted formats:** `.png`, `.jpg`, `.webp`
**Recommended specs:** PNG with transparency, square or consistent aspect ratio per category

### `kiosk-carousel/`
Promotional images displayed in the kiosk carousel/attract loop.

Split into two environments — `live/` for production kiosks and `staging/` for dev/staging builds. Within each environment, images are organized by Company ID (CID) for merchant-specific overrides, with a `global/` fallback used when no CID folder exists.

| Path | Browse | Description |
|------|--------|-------------|
| `kiosk-carousel/` | [View all folders](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/kiosk-carousel/) | Navigate live and staging carousel image folders |

**Accepted formats:** `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`

**CID resolution logic (kiosk):**
- **Production:** requests `kiosk-carousel/live/<CID>/index.json`; falls back to `kiosk-carousel/live/global/index.json`
- **Dev/Staging:** requests `kiosk-carousel/staging/<CID>/index.json`; falls back to `kiosk-carousel/staging/global/index.json`

**`index.json` format** (auto-generated alongside `index.html` in each leaf folder):
```json
{
  "folder": "206100",
  "count": 1,
  "images": [
    { "name": "Levitea Promo.jpg", "url": "Levitea%20Promo.jpg" }
  ]
}
```

**Adding a new CID:**
1. Create a folder named with the 6-digit CID under the appropriate environment (e.g. `kiosk-carousel/live/206100/`).
2. Add the desired carousel images to that folder.
3. Commit and push — `index.html` and `index.json` are generated automatically.

### `documents/`
Printable or referenceable documents such as menus, nutrition guides, training materials, or compliance forms.

| Path | Browse | Description |
|------|--------|-------------|
| `documents/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/documents/) | All document assets |

**Accepted formats:** `.pdf`, `.docx`

### `sounds/`
Audio assets used for alerts, confirmations, or ambient experience on Kiosk and POS devices.

| Path | Browse | Description |
|------|--------|-------------|
| `sounds/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/sounds/) | All audio assets |

**Accepted formats:** `.mp3`, `.wav`, `.ogg`

### `videos/`
Video assets for screensavers, attract loops, or promotional display on Kiosk and consumer-facing screens.

| Path | Browse | Description |
|------|--------|-------------|
| `videos/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/videos/) | All video assets |

**Accepted formats:** `.mp4`, `.mov`, `.webm`

### `miscellaneous/`
Assets that do not clearly fit into any of the above categories. Prefer placing assets in a specific folder when possible.

| Path | Browse | Description |
|------|--------|-------------|
| `miscellaneous/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/miscellaneous/) | All miscellaneous assets |

---

## Naming Conventions

- Use **Title Case** with spaces for human-readable asset names (e.g., `Strawberry Milk Foam.png`).
- Names should match the **exact display name** used in FranPOS so assets can be mapped programmatically.
- Avoid special characters other than spaces, hyphens (`-`), and parentheses.

## Adding & Deploying Assets

### Prerequisites

If you haven't already, you'll need to clone this repository to your computer once:

```bash
git clone https://github.com/gerry-wood-sumup/franpos_auxiliary_dam.git
cd franpos_auxiliary_dam
```

You'll also need [Git](https://git-scm.com/downloads) installed. To check, run `git --version` in your terminal.

---

### Adding kiosk carousel images

**For staging** (dev/staging kiosk builds):

1. Copy your image file(s) into `kiosk-carousel/staging/global/` (or a CID folder, e.g. `kiosk-carousel/staging/206100/`).
2. Open a terminal in the repo folder and run:

```bash
git pull
git add kiosk-carousel/
git commit -m "Add carousel images to staging/global"
git push
```

**For live** (production kiosk builds):

1. Copy your image file(s) into `kiosk-carousel/live/global/` (or a CID folder, e.g. `kiosk-carousel/live/206100/`).
2. Run:

```bash
git pull
git add kiosk-carousel/
git commit -m "Add carousel images to live/global"
git push
```

After pushing, GitHub Actions will automatically regenerate all index files and deploy the updated site. Kiosks can then fetch the updated `index.json` from the appropriate path.

---

### Adding modifier images

1. Copy your image file(s) into `images/modifiers/toppings/` (or create a new subfolder for a different modifier group, e.g. `images/modifiers/syrups/`).
2. Name the file to match the exact display name used in FranPOS (e.g. `Strawberry Milk Foam.png`).
3. Run:

```bash
git pull
git add images/
git commit -m "Add modifier image: Strawberry Milk Foam"
git push
```

---

### Adding other assets

For documents, sounds, videos, or miscellaneous files, follow the same pattern — copy the file into the appropriate folder, then:

```bash
git pull
git add <folder-name>/
git commit -m "Add <brief description of what you added>"
git push
```

Replace `<folder-name>` with `documents`, `sounds`, `videos`, or `miscellaneous` as appropriate.

---

### Scheduling a deployment with a PR

If you want changes to go live at a specific date and time — for example, to coincide with a product launch — use a Pull Request with a `/schedule` command instead of pushing directly to `main`.

**Step 1 — Create a branch and commit your changes:**

```bash
git pull
git checkout -b add-levitea-promo
# copy your files into the appropriate folder, then:
git add kiosk-carousel/
git commit -m "Add Levitea promo images to live/global"
git push -u origin add-levitea-promo
```

**Step 2 — Open a Pull Request on GitHub:**

Go to the repository on GitHub. You'll see a prompt to open a PR for your new branch — click **Compare & pull request**.

**Step 3 — Add the `/schedule` command to the PR description:**

Anywhere in the PR description, add a line in this format:

```
/schedule 2026-05-01 9:00 AM EST
```

Supported timezones: `EST`, `EDT`, `CST`, `CDT`, `MST`, `MDT`, `PST`, `PDT`, `UTC`, `GMT`.

**Step 4 — Submit the PR.**

The [Scheduled PR Merge workflow](.github/workflows/merge-schedule.yml) checks all open PRs every 15 minutes. When your scheduled time arrives, it will automatically merge the PR into `main`, triggering the usual index regeneration and deploy pipeline. A comment will be posted on the PR confirming the merge.

> **Note:** Scheduled merges are only honoured for PRs opened by repository collaborators. PRs from forks or external contributors with a `/schedule` command will be silently skipped.

**To cancel:** Simply close the PR, or edit the description to remove the `/schedule` line before the time is reached.

---

### Tips

- Always run `git pull` before adding files to make sure your local copy is up to date.
- If you're unsure whether your push worked, check the [Actions tab](https://github.com/gerry-wood-sumup/franpos_auxiliary_dam/actions) — a green checkmark means the site has been updated successfully.
- Index pages update automatically — you never need to edit `index.html` or `index.json` files by hand.

---

## Browsing & Managing Assets

Each media folder contains an `index.html` that lists every asset with a preview thumbnail and its direct URL. These pages are served automatically via **GitHub Pages**.

Navigate the index pages by starting at the top-level folder for the media type you need (e.g., `images/modifiers/toppings/index.html`) and following the breadcrumb links.

> Index pages are auto-generated — do not edit them by hand. Changes will be overwritten on the next push.

### In-Page Management UI

Every index page includes a built-in management bar that lets you upload, delete, and regenerate indexes directly from the browser — no git client required.

**Supported actions:**

- **Upload Files** — select files via the button or drag and drop them onto the drop zone. Files are **staged** first (nothing is uploaded yet); the drop zone confirms what's queued and the button label updates to **Upload N files**. Fill in any subfolder before clicking to confirm.
  - On **asset pages** (e.g. `kiosk-carousel/live/global/`), files are added directly to the current folder.
  - On **directory pages** (e.g. `kiosk-carousel/live/`), an optional **Subfolder** field lets you type a CID (e.g. `206100`) to upload files directly into a new or existing CID folder — no need to create the folder separately first.
  - Click **✕ clear** in the drop zone to de-stage files without uploading.
- **Delete File** — removes an individual asset from the current folder; a confirmation prompt is shown before anything is deleted.
- **Delete Folder** — removes an entire CID folder and all its contents in one step; available on directory pages next to each deletable folder row.
- **Regenerate Indexes** — manually triggers an index rebuild without changing any files; useful if the indexes ever appear stale.

After any upload or delete, indexes are automatically regenerated and the page reloads once the pipeline completes (typically under 60 seconds).

**Protected folders** — the following folders are structural and cannot be deleted through the UI:

| Folder | Why protected |
|--------|--------------|
| `kiosk-carousel/live/` | Required for production kiosk resolution |
| `kiosk-carousel/staging/` | Required for dev/staging kiosk resolution |
| `kiosk-carousel/live/global/` | Default fallback for all live kiosks |
| `kiosk-carousel/staging/global/` | Default fallback for all staging kiosks |

CID-specific folders (e.g. `kiosk-carousel/live/206100/`) can be freely created and deleted.

#### Setting up a GitHub Personal Access Token (PAT)

The management UI authenticates with GitHub using a classic Personal Access Token. You'll need to create one once:

1. Go to **GitHub → Settings → Developer Settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name (e.g. `DAM Management`) and set an expiration
4. Under **Scopes**, tick:
   - **`repo`** — full repository read/write access
   - **`workflow`** — allows triggering GitHub Actions workflows
5. Click **Generate token** and copy it — it won't be shown again

To use it: open any DAM index page, paste the token into the **Connect** bar at the top of the page, and click **Connect**. Your session stays connected until you close the browser tab or click Disconnect. The token is stored only in your browser's session memory and is never sent anywhere except the GitHub API.

---

## Automation

### Index Page Generation & Deployment

On every push to `main`, the **GitHub Actions workflow** ([`.github/workflows/generate-indexes.yml`](.github/workflows/generate-indexes.yml)) handles the full pipeline:

1. Runs [`scripts/generate-indexes.sh`](scripts/generate-indexes.sh) to regenerate all `index.html` files
2. Commits any updated `index.html` files back to `main`
3. Deploys the site to GitHub Pages

This ensures Pages is always deployed with up-to-date indexes, and only once per push. GitHub Pages is configured to deploy via **GitHub Actions** (not from a branch).

**The script discovers media directories automatically.** Any new top-level directory added to the repo (e.g., `videos/`, `sounds/`) will be scanned and indexed as long as it contains supported media files. No configuration changes are required.

Directories excluded from scanning: `.git`, `.github`, `scripts`, `node_modules`. To exclude additional directories, edit the `EXCLUDED_DIRS` array at the top of `scripts/generate-indexes.sh`.

To regenerate indexes locally before pushing:

```bash
bash scripts/generate-indexes.sh
```

### Scheduled PR Merges

The workflow [`.github/workflows/merge-schedule.yml`](.github/workflows/merge-schedule.yml) runs every 15 minutes and auto-merges any open PR whose description contains a `/schedule` command once the specified date and time is reached.

**Command format** (add anywhere in the PR body):
```
/schedule 2026-04-25 10:30 AM EST
```

Supported timezone abbreviations: `EST`, `EDT`, `CST`, `CDT`, `MST`, `MDT`, `PST`, `PDT`, `UTC`, `GMT`.

When the PR is merged the workflow posts a comment confirming the scheduled merge. If the merge fails (e.g. conflicts or branch protection), a failure comment is posted instead so the author is notified.

The workflow can also be triggered manually via **Actions → Scheduled PR Merge → Run workflow** to test without waiting for the next cron tick.

### Search Engine Blocking

A [`robots.txt`](robots.txt) at the repo root instructs all crawlers to not index any content on the GitHub Pages site.
