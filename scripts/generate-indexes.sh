#!/usr/bin/env bash
# scripts/generate-indexes.sh
#
# Regenerates index.html files for every media folder in the repo.
# - Folders containing media files   → file listing with thumbnails/links + management UI
# - Folders containing subdirectories → directory listing + management UI
#
# Management UI: each generated page embeds a GitHub API-powered management bar
# (upload, delete, regenerate) authenticated via a Personal Access Token (PAT).
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

# Parse GitHub repo identity for the in-page management UI
REMOTE_URL="$(git remote get-url origin 2>/dev/null || echo "")"
REPO_OWNER="$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')"
REPO_NAME="$(echo "$REMOTE_URL"  | sed -E 's|.*github\.com[:/][^/]+/([^/.]+).*|\1|')"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
}

# Build breadcrumb HTML for a relative path like "images/modifiers/toppings"
# Always prepends a Home link back to the site root.
build_breadcrumb() {
  local rel_path="$1"
  IFS='/' read -ra parts <<< "$rel_path"
  local depth="${#parts[@]}"

  # Compute the path back to the root from this depth
  local root_ups=""
  for (( k=0; k<depth; k++ )); do root_ups="../$root_ups"; done
  local result="<a href=\"${root_ups}index.html\">Home</a> / "

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
    #auth-bar { position: sticky; top: 0; background: #fff; border-bottom: 1px solid #ddd; padding: 0.6rem 0; margin-bottom: 1.5rem; display: flex; align-items: center; gap: 0.75rem; font-size: 0.85rem; z-index: 10; flex-wrap: wrap; }
    #auth-bar input[type="password"] { border: 1px solid #ccc; border-radius: 4px; padding: 0.3rem 0.5rem; font-size: 0.85rem; width: 260px; font-family: monospace; }
    .btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; border: none; border-radius: 4px; font-size: 0.82rem; cursor: pointer; white-space: nowrap; }
    .btn-primary   { background: #0066cc; color: #fff; }
    .btn-success   { background: #2da44e; color: #fff; }
    .btn-danger    { background: #cf222e; color: #fff; font-size: 0.75rem; padding: 0.2rem 0.5rem; }
    .btn-secondary { background: #eee;    color: #333; }
    .btn:disabled  { opacity: 0.5; cursor: not-allowed; }
    .toolbar { display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap; align-items: center; }
    .subfolder-wrap { display: flex; align-items: center; gap: 0.4rem; font-size: 0.82rem; color: #555; }
    .subfolder-wrap input { border: 1px solid #ccc; border-radius: 4px; padding: 0.3rem 0.5rem; font-size: 0.82rem; width: 130px; }
    .drop-zone { border: 2px dashed #ccc; border-radius: 6px; padding: 0.75rem 1rem; color: #888; font-size: 0.85rem; margin-bottom: 1rem; transition: background 0.15s, border-color 0.15s; cursor: pointer; }
    .drop-zone.dragover { background: #f0f7ff; border-color: #0066cc; color: #0066cc; }
    #toast-container { position: fixed; bottom: 1.5rem; right: 1.5rem; display: flex; flex-direction: column; gap: 0.5rem; z-index: 100; pointer-events: none; }
    .toast { padding: 0.6rem 1rem; border-radius: 6px; color: #fff; font-size: 0.85rem; max-width: 340px; box-shadow: 0 2px 8px rgba(0,0,0,.15); animation: dam-fadein 0.2s; pointer-events: auto; }
    .toast-success { background: #2da44e; }
    .toast-error   { background: #cf222e; }
    @keyframes dam-fadein { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
CSS
}

shared_js() {
  cat <<'JS'
<script>
(function () {
  // DAM_OWNER, DAM_REPO, DAM_PATH, DAM_IS_DIR are injected per-page before this script.
  if (!DAM_OWNER || !DAM_REPO) return;

  const API_REPO = 'https://api.github.com/repos/' + DAM_OWNER + '/' + DAM_REPO;

  // ── Token storage (sessionStorage — cleared when tab closes) ───────────────
  const getToken = () => sessionStorage.getItem('dam_pat');
  const setToken = (t) => sessionStorage.setItem('dam_pat', t);
  const getUser  = () => sessionStorage.getItem('dam_user');
  const setUser  = (u) => sessionStorage.setItem('dam_user', u);
  const clearAuth = () => { sessionStorage.removeItem('dam_pat'); sessionStorage.removeItem('dam_user'); };

  // ── GitHub API wrapper ─────────────────────────────────────────────────────
  async function ghApi(method, url, body) {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const opts = {
      method,
      headers: {
        Authorization: 'Bearer ' + token,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    };
    if (body !== undefined) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    const fullUrl = url.startsWith('https://') ? url : API_REPO + url;
    const res = await fetch(fullUrl, opts);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || 'HTTP ' + res.status);
    return data;
  }

  // ── Toast notifications ────────────────────────────────────────────────────
  function toast(msg, type) {
    type = type || 'success';
    const el = document.createElement('div');
    el.className = 'toast toast-' + type;
    el.textContent = msg;
    document.getElementById('toast-container').appendChild(el);
    if (type === 'success') setTimeout(() => el.remove(), 4000);
    return el;
  }

  // ── Show/hide management controls ─────────────────────────────────────────
  function setMgmtVisible(visible) {
    document.querySelectorAll('.mgmt').forEach(function (el) {
      el.style.display = visible ? '' : 'none';
    });
  }

  // ── Auth bar ───────────────────────────────────────────────────────────────
  async function verifyAndConnect(token) {
    const prev = getToken();
    setToken(token);
    try {
      const user = await ghApi('GET', 'https://api.github.com/user');
      setUser(user.login);
      return user.login;
    } catch (e) {
      prev ? setToken(prev) : clearAuth();
      throw e;
    }
  }

  function renderAuthBar() {
    const bar = document.getElementById('auth-bar');
    const token = getToken();
    const user = getUser();

    if (token && user) {
      bar.innerHTML =
        '<span>🔑 Connected as <strong>@' + user + '</strong></span>' +
        '<button class="btn btn-secondary" id="dam-disconnect">Disconnect</button>' +
        '<span style="flex:1"></span>' +
        '<button class="btn btn-secondary" id="dam-regen">↻ Regenerate Indexes</button>';

      document.getElementById('dam-disconnect').onclick = function () {
        clearAuth();
        renderAuthBar();
        setMgmtVisible(false);
      };
      document.getElementById('dam-regen').onclick = standaloneRegen;
      setMgmtVisible(true);
    } else {
      bar.innerHTML =
        '<input type="password" id="dam-pat-input" placeholder="Paste your GitHub Personal Access Token" autocomplete="off" />' +
        '<button class="btn btn-primary" id="dam-connect">Connect</button>';

      async function doConnect() {
        const input = document.getElementById('dam-pat-input');
        const btn = document.getElementById('dam-connect');
        const val = input.value.trim();
        if (!val) return;
        btn.disabled = true;
        btn.textContent = 'Connecting…';
        try {
          const login = await verifyAndConnect(val);
          toast('Connected as @' + login);
          renderAuthBar();
        } catch (e) {
          toast('Authentication failed: ' + e.message, 'error');
          btn.disabled = false;
          btn.textContent = 'Connect';
        }
      }

      document.getElementById('dam-connect').onclick = doConnect;
      document.getElementById('dam-pat-input').addEventListener('keydown', function (e) {
        if (e.key === 'Enter') doConnect();
      });
      setMgmtVisible(false);
    }
  }

  // ── Regenerate + poll + reload ─────────────────────────────────────────────
  async function triggerRegen() {
    await ghApi('POST', '/actions/workflows/generate-indexes.yml/dispatches', { ref: 'main' });
  }

  async function waitForRegenAndReload() {
    const t = toast('Regenerating indexes — page will reload when done…');
    await new Promise(function (r) { setTimeout(r, 4000); }); // let GHA queue the run
    for (var i = 0; i < 72; i++) { // poll up to ~6 minutes
      await new Promise(function (r) { setTimeout(r, 5000); });
      try {
        const data = await ghApi('GET', '/actions/workflows/generate-indexes.yml/runs?per_page=1');
        const run = data.workflow_runs && data.workflow_runs[0];
        if (run && run.status === 'completed') { location.reload(); return; }
      } catch (_) { /* ignore polling errors */ }
    }
    t.remove();
    toast('Regeneration is taking longer than expected — please refresh manually.', 'error');
  }

  async function standaloneRegen() {
    const btn = document.getElementById('dam-regen');
    if (btn) { btn.disabled = true; btn.textContent = '↻ Triggering…'; }
    try {
      await triggerRegen();
      toast('Regeneration triggered — indexes will update shortly');
    } catch (e) {
      toast('Failed to trigger regeneration: ' + e.message, 'error');
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = '↻ Regenerate Indexes'; }
    }
  }

  // ── Disable / enable all interactive elements ──────────────────────────────
  function setDisabled(disabled) {
    document.querySelectorAll('button, input').forEach(function (el) { el.disabled = disabled; });
  }

  // ── File helpers ───────────────────────────────────────────────────────────
  function toBase64(file) {
    return new Promise(function (resolve, reject) {
      const reader = new FileReader();
      reader.onload = function () { resolve(reader.result.split(',')[1]); };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  async function uploadFiles(files, subfolder) {
    const base = subfolder
      ? DAM_PATH + '/' + subfolder.replace(/^\/|\/$/g, '')
      : DAM_PATH;
    var done = 0;
    for (var i = 0; i < files.length; i++) {
      const file = files[i];
      const content = await toBase64(file);
      const filePath = base + '/' + file.name;
      var sha;
      try {
        const existing = await ghApi('GET', '/contents/' + filePath);
        sha = existing.sha;
      } catch (_) { /* new file */ }
      const body = { message: 'Upload ' + file.name + ' via DAM', content: content };
      if (sha) body.sha = sha;
      await ghApi('PUT', '/contents/' + filePath, body);
      toast('Uploaded ' + (++done) + '/' + files.length + ': ' + file.name);
    }
  }

  async function deleteFile(filePath) {
    const existing = await ghApi('GET', '/contents/' + filePath);
    await ghApi('DELETE', '/contents/' + filePath, {
      message: 'Delete ' + filePath.split('/').pop() + ' via DAM',
      sha: existing.sha,
    });
  }

  // ── Upload wiring ──────────────────────────────────────────────────────────
  function wireUpload() {
    const uploadBtn  = document.getElementById('dam-upload-btn');
    const fileInput  = document.getElementById('dam-file-input');
    const dropZone   = document.getElementById('dam-drop-zone');
    const subInput   = document.getElementById('dam-subfolder');
    if (!uploadBtn || !fileInput) return;

    const getSubfolder = function () { return subInput ? subInput.value.trim() : ''; };

    async function handleFiles(files) {
      if (!files.length) return;
      setDisabled(true);
      try {
        await uploadFiles(Array.from(files), getSubfolder());
        await triggerRegen();
        await waitForRegenAndReload();
      } catch (e) {
        toast('Upload failed: ' + e.message, 'error');
        setDisabled(false);
      }
    }

    uploadBtn.onclick = function () { fileInput.click(); };
    fileInput.onchange = function () { handleFiles(fileInput.files); };

    if (dropZone) {
      dropZone.addEventListener('dragover', function (e) {
        e.preventDefault();
        dropZone.classList.add('dragover');
      });
      dropZone.addEventListener('dragleave', function () {
        dropZone.classList.remove('dragover');
      });
      dropZone.addEventListener('drop', function (e) {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        handleFiles(e.dataTransfer.files);
      });
      dropZone.addEventListener('click', function () { fileInput.click(); });
    }
  }

  // ── Delete wiring ──────────────────────────────────────────────────────────
  function wireDelete() {
    document.querySelectorAll('.dam-delete-btn').forEach(function (btn) {
      btn.onclick = async function () {
        const filePath = btn.dataset.path;
        const fileName = filePath.split('/').pop();
        if (!confirm('Delete "' + fileName + '"?\n\nThis cannot be undone.')) return;
        setDisabled(true);
        try {
          await deleteFile(filePath);
          await triggerRegen();
          await waitForRegenAndReload();
        } catch (e) {
          toast('Delete failed: ' + e.message, 'error');
          setDisabled(false);
        }
      };
    });
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', function () {
    renderAuthBar();
    wireUpload();
    wireDelete();
  });
})();
</script>
JS
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
  <div id="auth-bar"></div>
  <div id="toast-container"></div>
  <div class="breadcrumb">${breadcrumb}</div>
  <h1>${folder_name}</h1>
  <p class="count">${count} image${plural}</p>
  <div class="toolbar mgmt" style="display:none">
    <button class="btn btn-primary" id="dam-upload-btn">⬆ Upload Files</button>
    <input type="file" id="dam-file-input" multiple style="display:none">
  </div>
  <div class="drop-zone mgmt" id="dam-drop-zone" style="display:none">Drop image files here, or click to browse</div>
  <table>
    <thead>
      <tr>
        <th>Preview</th>
        <th>File Name</th>
        <th>Path</th>
        <th class="mgmt" style="display:none">Actions</th>
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
        <td class="mgmt" style="display:none">
          <button class="btn btn-danger dam-delete-btn" data-path="${rel_dir}/${img}">Delete</button>
        </td>
      </tr>
HTML
    done

    cat <<HTML
    </tbody>
  </table>
  <script>
    var DAM_OWNER  = '${REPO_OWNER}';
    var DAM_REPO   = '${REPO_NAME}';
    var DAM_PATH   = '${rel_dir}';
    var DAM_IS_DIR = false;
  </script>
HTML
    shared_js
    cat <<HTML
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
    breadcrumb="<a href=\"../index.html\">Home</a> / $folder_name"
  else
    breadcrumb="$(build_breadcrumb "$rel_dir")"
  fi

  local subdirs=()
  while IFS= read -r -d $'\0' subdir; do
    subdirs+=("$(basename "$subdir")")
  done < <(
    find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -print0 | sort -z
  )

  # For direct children of kiosk-carousel (live/, staging/): pin global first, then CIDs numerically
  local parent_name
  parent_name="$(basename "$(dirname "$dir")")"
  if [[ "$parent_name" == "kiosk-carousel" ]]; then
    local cid_dirs=()
    for d in "${subdirs[@]}"; do
      [[ "$d" != "global" ]] && cid_dirs+=("$d")
    done
    if (( ${#cid_dirs[@]} > 0 )); then
      IFS=$'\n' read -r -d '' -a cid_dirs <<< "$(printf '%s\n' "${cid_dirs[@]}" | sort -n)" || true
    fi
    subdirs=("global" ${cid_dirs[@]+"${cid_dirs[@]}"})
  fi

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
  <div id="auth-bar"></div>
  <div id="toast-container"></div>
  <div class="breadcrumb">${breadcrumb}</div>
  <h1>${folder_name}</h1>
  <div class="toolbar mgmt" style="display:none">
    <button class="btn btn-primary" id="dam-upload-btn">⬆ Upload Files</button>
    <input type="file" id="dam-file-input" multiple style="display:none">
    <span class="subfolder-wrap">
      into subfolder: <input type="text" id="dam-subfolder" placeholder="e.g. 206100 (optional)">
    </span>
  </div>
  <div class="drop-zone mgmt" id="dam-drop-zone" style="display:none">Drop files here to upload (into subfolder if specified above), or click to browse</div>
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
  <script>
    var DAM_OWNER  = '${REPO_OWNER}';
    var DAM_REPO   = '${REPO_NAME}';
    var DAM_PATH   = '${rel_dir}';
    var DAM_IS_DIR = true;
  </script>
HTML
    shared_js
    cat <<HTML
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
