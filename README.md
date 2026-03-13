# franpos_auxiliary_dam

This repository is the **Digital Asset Management (DAM)** store for auxiliary media leveraged by the FranPOS POS, Kiosk, and other merchant and consumer-facing devices.

---

## Repository Structure

```
franpos_modifier_cms/
├── images/
│   └── modifiers/
│       └── toppings/
├── documents/
├── sounds/
├── videos/
└── miscellaneous/
```

### `images/`
Static image assets displayed across POS, Kiosk, and consumer-facing surfaces.

Organized by the modifier/menu category they belong to:

| Path | Description |
|------|-------------|
| `images/modifiers/toppings/` | Topping modifier images shown on the Kiosk and POS modifier selection screens |

**Accepted formats:** `.png`, `.jpg`, `.webp`
**Recommended specs:** PNG with transparency, square or consistent aspect ratio per category

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
