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
│   ├── global/
│   └── <CID>/          (6-digit numeric Company ID, e.g. 206100)
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
| `images/modifiers/toppings/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/images/modifiers/toppings/) | Topping modifier images shown on the Kiosk and POS modifier selection screens |

**Accepted formats:** `.png`, `.jpg`, `.webp`
**Recommended specs:** PNG with transparency, square or consistent aspect ratio per category

### `kiosk-carousel/`
Promotional images displayed in the kiosk carousel/attract loop.

Organized by Company ID (CID) for merchant-specific overrides, with a `global/` fallback:

| Path | Browse | Description |
|------|--------|-------------|
| `kiosk-carousel/global/` | [View assets](https://gerry-wood-sumup.github.io/franpos_auxiliary_dam/kiosk-carousel/global/) | Default carousel images used by any kiosk without a CID-specific folder |
| `kiosk-carousel/<CID>/` | — | Carousel images for a specific merchant (6-digit numeric CID, e.g. `206100`) |

**Accepted formats:** `.png`, `.jpg`, `.webp`

**CID resolution logic (kiosk):** The kiosk requests `kiosk-carousel/<CID>/index.json`. If that path does not exist, it falls back to `kiosk-carousel/global/index.json`.

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
1. Create a folder named with the 6-digit CID under `kiosk-carousel/` (e.g. `kiosk-carousel/206100/`).
2. Add the desired carousel images to that folder.
3. Commit and push — `index.html` and `index.json` are generated automatically.

### `documents/`
Printable or referenceable documents such as menus, nutrition guides, training materials, or compliance forms.

**Accepted formats:** `.pdf`, `.docx`

### `sounds/`
Audio assets used for alerts, confirmations, or ambient experience on Kiosk and POS devices.

**Accepted formats:** `.mp3`, `.wav`, `.ogg`

### `videos/`
Video assets for screensavers, attract loops, or promotional display on Kiosk and consumer-facing screens.

**Accepted formats:** `.mp4`, `.mov`, `.webm`

### `miscellaneous/`
Assets that do not clearly fit into any of the above categories. Prefer placing assets in a specific folder when possible.

---

## Naming Conventions

- Use **Title Case** with spaces for human-readable asset names (e.g., `Strawberry Milk Foam.png`).
- Names should match the **exact display name** used in FranPOS so assets can be mapped programmatically.
- Avoid special characters other than spaces, hyphens (`-`), and parentheses.

## Adding New Assets

1. Place the file in the appropriate folder for its media type.
2. For images under `modifiers/`, create a subfolder matching the modifier group name if one does not already exist (e.g., `images/modifiers/syrups/`).
3. Ensure the filename matches the FranPOS modifier/item display name exactly.
4. Commit with a descriptive message indicating what was added and which menu category it belongs to.

---

## Browsing Assets

Each media folder contains an `index.html` that lists every asset with a preview thumbnail and its direct URL. These pages are served automatically via **GitHub Pages**.

Navigate the index pages by starting at the top-level folder for the media type you need (e.g., `images/modifiers/toppings/index.html`) and following the breadcrumb links.

> Index pages are auto-generated — do not edit them by hand. Changes will be overwritten on the next push.

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

### Search Engine Blocking

A [`robots.txt`](robots.txt) at the repo root instructs all crawlers to not index any content on the GitHub Pages site.
