#!/usr/bin/env bash
# scripts/generate-indexes.sh
#
# Regenerates index.html files for every media folder in the repo.
# - Folders containing media files   → file listing with thumbnails/links
# - Folders containing subdirectories → directory listing
#
# Any top-level directory not in EXCLUDED_DIRS that contains media files
# somewhere in its subtree will be scanned automatically — no config needed
# when new media directories are added.
#
# Run manually: bash scripts/generate-indexes.sh
# Run automatically: via the GitHub Actions workflow on push.

# Top-level directories to never scan (system / non-media dirs)
EXCLUDED_DIRS=(".git" ".github" "scripts" "node_modules")

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
}

# Build breadcrumb HTML for a relative path like "images/modifiers/toppings"
build_breadcrumb() {
  local rel_path="$1"
  IFS='/' read -ra parts <<< "$rel_path"
  local depth="${#parts[@]}"
  local result=""

  for (( i=0; i<depth; i++ )); do
    local part="${parts[$i]}"
    if (( i < depth - 1 )); then
      local ups=""
      for (( j=i+1; j<depth; j++ )); do ups="../$ups"; done
      result+="<a href=\"${ups}index.html\">$part</a> / "
    else
      result+="$part"
    fi
  done
  echo "$result"
}

shared_css() {
  cat <<'CSS'
    body { font-family: sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem; color: #222; }
    h1 { font-size: 1.4rem; margin-bottom: 0.25rem; text-transform: capitalize; }
    .breadcrumb { font-size: 0.85rem; color: #666; margin-bottom: 1.5rem; }
    .breadcrumb a { color: #0066cc; text-decoration: none; }
    .breadcrumb a:hover { text-decoration: underline; }
    table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    th { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 2px solid #ddd; color: #555; font-weight: 600; }
    td { padding: 0.5rem 0.75rem; border-bottom: 1px solid #eee; vertical-align: middle; }
    tr:hover td { background: #f7f7f7; }
    .thumb { width: 48px; height: 48px; object-fit: contain; border-radius: 4px; background: #f0f0f0; }
    a { color: #0066cc; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .folder::before { content: "📁 "; }
    .count { color: #888; font-size: 0.8rem; margin-bottom: 1rem; }
CSS
}

# ---------------------------------------------------------------------------
# Leaf directory: contains image files directly
# ---------------------------------------------------------------------------

generate_leaf_index() {
  local dir="$1"
  local rel_dir="${dir#./}"
  local folder_name
  folder_name="$(basename "$dir")"
  local breadcrumb
  breadcrumb="$(build_breadcrumb "$rel_dir")"

  # Collect sorted image filenames
  local images=()
  while IFS= read -r img; do
    [[ -n "$img" ]] && images+=("$img")
  done < <(
    find "$dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" \) -exec basename {} \; | sort
  )

  local count="${#images[@]}"
  local plural; (( count != 1 )) && plural="s" || plural=""

  {
    cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${folder_name} — DAM</title>
  <style>
$(shared_css)
  </style>
</head>
<body>
  <div class="breadcrumb">${breadcrumb}</div>
  <h1>${folder_name}</h1>
  <p class="count">${count} image${plural}</p>
  <table>
    <thead>
      <tr>
        <th>Preview</th>
        <th>File Name</th>
        <th>Path</th>
      </tr>
    </thead>
    <tbody>
HTML

    for img in "${images[@]}"; do
      local href
      href="$(echo "$img" | urlencode)"
      local alt="${img%.*}"
      cat <<HTML
      <tr>
        <td><img class="thumb" src="${href}" alt="${alt}"></td>
        <td><a href="${href}">${img}</a></td>
        <td>${rel_dir}/${img}</td>
      </tr>
HTML
    done

    cat <<HTML
    </tbody>
  </table>
</body>
</html>
HTML
  } > "$dir/index.html"

  echo "  Generated: $dir/index.html ($count image${plural})"
}

# ---------------------------------------------------------------------------
# Leaf directory (kiosk-carousel only): also generate index.json for kiosk
# ---------------------------------------------------------------------------

generate_json_index() {
  local dir="$1"
  local folder_name
  folder_name="$(basename "$dir")"

  local images=()
  while IFS= read -r img; do
    [[ -n "$img" ]] && images+=("$img")
  done < <(
    find "$dir" -maxdepth 1 -type f \
      \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" \) \
      -exec basename {} \; | sort
  )

  local count="${#images[@]}"
  {
    echo "{"
    echo "  \"folder\": \"${folder_name}\","
    echo "  \"count\": ${count},"
    echo "  \"images\": ["
    local i=0
    for img in "${images[@]}"; do
      local encoded
      encoded="$(echo "$img" | urlencode)"
      local comma=""
      (( i < count - 1 )) && comma=","
      echo "    { \"name\": \"${img}\", \"url\": \"${encoded}\" }${comma}"
      (( i++ )) || true
    done
    echo "  ]"
    echo "}"
  } > "$dir/index.json"

  echo "  Generated: $dir/index.json ($count image(s))"
}

# ---------------------------------------------------------------------------
# Parent directory: contains subdirectories
# ---------------------------------------------------------------------------

generate_dir_index() {
  local dir="$1"
  local rel_dir="${dir#./}"
  local folder_name
  folder_name="$(basename "$dir")"

  local breadcrumb
  if [[ "$rel_dir" == "$folder_name" ]]; then
    breadcrumb="$folder_name"
  else
    breadcrumb="$(build_breadcrumb "$rel_dir")"
  fi

  local subdirs=()
  while IFS= read -r -d $'\0' subdir; do
    subdirs+=("$(basename "$subdir")")
  done < <(
    find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -print0 | sort -z
  )

  {
    cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${folder_name} — DAM</title>
  <style>
$(shared_css)
  </style>
</head>
<body>
  <div class="breadcrumb">${breadcrumb}</div>
  <h1>${folder_name}</h1>
  <table>
    <thead>
      <tr>
        <th>Folder</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
HTML

    for subdir in "${subdirs[@]}"; do
      cat <<HTML
      <tr>
        <td class="folder"><a href="${subdir}/index.html">${subdir}</a></td>
        <td></td>
      </tr>
HTML
    done

    cat <<HTML
    </tbody>
  </table>
</body>
</html>
HTML
  } > "$dir/index.html"

  local dir_suffix; (( ${#subdirs[@]} != 1 )) && dir_suffix="ies" || dir_suffix="y"
  echo "  Generated: $dir/index.html (${#subdirs[@]} subdirector${dir_suffix})"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Returns 0 if a directory contains any media files anywhere in its subtree
dir_has_media() {
  find "$1" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mp3" -o -iname "*.wav" -o -iname "*.pdf" \) -print -quit 2>/dev/null | grep -q .
}

# Returns 0 if a directory name is in EXCLUDED_DIRS
is_excluded() {
  local name="$1"
  for excluded in "${EXCLUDED_DIRS[@]}"; do
    [[ "$name" == "$excluded" ]] && return 0
  done
  return 1
}

echo "Generating index files..."

# Find all non-hidden top-level directories, skip excluded ones,
# skip any that contain no media — then scan all subdirs within each.
while IFS= read -r -d $'\0' root; do
  root_name="$(basename "$root")"
  is_excluded "$root_name" && continue
  dir_has_media "$root" || continue

  echo "Scanning: $root"
  while IFS= read -r -d $'\0' dir; do
    image_count=$(find "$dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" \) 2>/dev/null | wc -l | tr -d ' ')

    if (( image_count > 0 )); then
      generate_leaf_index "$dir"
      if [[ "$dir" == *"kiosk-carousel"* ]]; then
        generate_json_index "$dir"
      fi
    else
      generate_dir_index "$dir"
    fi
  done < <(find "$root" -type d -not -name '.*' -print0 | sort -z)

done < <(find . -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

echo "Done."
