# Web UI: Default Path & Folder Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add auto-fill for `~/WorkingProjects/<name>` in the new workspace form, and add "Browse..." buttons that open a macOS native folder picker dialog via osascript.

**Architecture:** A new `GET /pick-folder` FastAPI endpoint runs `osascript` to open macOS's native folder selection dialog and returns the POSIX path. The frontend uses `fetch()` to call this endpoint and populate path input fields. Auto-fill is handled with vanilla JavaScript on the Name field's `input` event.

**Tech Stack:** FastAPI, Jinja2 templates, HTMX, Tailwind CSS, vanilla JavaScript, osascript (macOS)

---

### Task 1: Add `/pick-folder` endpoint to the backend

**Files:**
- Modify: `web/main.py` (after the `health` endpoint, around line 77)

**Step 1: Add the endpoint**

Insert the following after the `health()` function (after line 77, before the `templates.env.filters` line):

```python
@app.get("/pick-folder")
async def pick_folder():
    """Open macOS native folder selection dialog via osascript and return POSIX path."""
    # Step 1: Show native folder picker
    result = subprocess.run(
        ["osascript", "-e", 'choose folder with prompt "Select a folder:"'],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        # User cancelled or osascript unavailable
        return {"path": ""}

    # Step 2: Convert AppleScript alias to POSIX path
    alias = result.stdout.strip()
    posix_result = subprocess.run(
        ["osascript", "-e", f"POSIX path of ({alias})"],
        capture_output=True,
        text=True,
    )
    if posix_result.returncode != 0:
        return {"path": ""}

    # Strip trailing slash
    path = posix_result.stdout.strip().rstrip("/")
    return {"path": path}
```

**Step 2: Manual test**

Start the server: `cw web` (or `cd web && python -m uvicorn main:app --reload`)

In a browser or terminal:
```bash
curl http://localhost:8899/pick-folder
```
Expected: A folder selection dialog appears. After selecting a folder:
```json
{"path":"/Users/you/some/folder"}
```
If cancelled: `{"path":""}`

**Step 3: Commit**

```bash
git add web/main.py
git commit -m "feat(web): add /pick-folder endpoint for macOS native folder dialog"
```

---

### Task 2: Update `new.html` — auto-fill + Browse buttons

**Files:**
- Modify: `web/templates/new.html`

**Goal:**
- Name field → auto-fills `workspace_path` with `~/WorkingProjects/<slug>`
- "Browse..." button beside `workspace_path` field
- "Browse..." button beside `initial_dir` field

**Step 1: Replace the entire content of `new.html`**

Replace the full file content with:

```html
{% extends "base.html" %}

{% block title %}New Workspace — claude-workspace{% endblock %}

{% block content %}
<div class="mb-6 flex items-center gap-3">
  <a href="/" class="text-gray-500 hover:text-gray-300 text-sm">← Workspaces</a>
</div>

<div class="bg-gray-900 border border-gray-800 rounded-lg p-6 max-w-xl">
  <h1 class="text-xl font-bold text-white mb-6">New Workspace</h1>

  <form method="post" action="/workspace" class="space-y-4">
    <div>
      <label class="block text-sm text-gray-400 mb-1">Name <span class="text-red-400">*</span></label>
      <input type="text" id="ws-name" name="name" required autofocus
             placeholder="My Project"
             class="w-full bg-gray-800 border border-gray-700 text-gray-200 rounded px-3 py-2 text-sm focus:outline-none focus:border-orange-500">
    </div>

    <div>
      <label class="block text-sm text-gray-400 mb-1">Description</label>
      <input type="text" name="description"
             placeholder="Brief description of this workspace"
             class="w-full bg-gray-800 border border-gray-700 text-gray-200 rounded px-3 py-2 text-sm focus:outline-none focus:border-orange-500">
    </div>

    <div>
      <label class="block text-sm text-gray-400 mb-1">Workspace directory <span class="text-red-400">*</span></label>
      <div class="flex gap-2">
        <input type="text" id="ws-path" name="workspace_path" required
               placeholder="~/WorkingProjects/my-project"
               class="flex-1 bg-gray-800 border border-gray-700 text-gray-200 rounded px-3 py-2 text-sm focus:outline-none focus:border-orange-500">
        <button type="button" id="browse-ws-path"
                onclick="pickFolder('ws-path', 'browse-ws-path')"
                class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-2 rounded transition-colors whitespace-nowrap">
          Browse...
        </button>
      </div>
      <p class="text-gray-600 text-xs mt-1">Directory will be created if it doesn't exist.</p>
    </div>

    <div>
      <label class="block text-sm text-gray-400 mb-1">Initial directory (optional)</label>
      <div class="flex gap-2">
        <input type="text" id="initial-dir" name="initial_dir"
               placeholder="/path/to/repo"
               class="flex-1 bg-gray-800 border border-gray-700 text-gray-200 rounded px-3 py-2 text-sm focus:outline-none focus:border-orange-500">
        <button type="button" id="browse-initial-dir"
                onclick="pickFolder('initial-dir', 'browse-initial-dir')"
                class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-2 rounded transition-colors whitespace-nowrap">
          Browse...
        </button>
      </div>
    </div>

    {% if error %}
    <div class="text-red-400 text-sm bg-red-950 border border-red-900 rounded px-3 py-2">
      {{ error }}
    </div>
    {% endif %}

    <div class="flex gap-3 pt-2">
      <button type="submit"
              class="bg-orange-500 hover:bg-orange-400 text-white text-sm px-5 py-2 rounded transition-colors">
        Create Workspace
      </button>
      <a href="/" class="border border-gray-700 hover:border-gray-500 text-gray-400 hover:text-gray-200 text-sm px-5 py-2 rounded transition-colors">
        Cancel
      </a>
    </div>
  </form>
</div>

<script>
  // ── Auto-fill workspace_path from Name ──────────────────────────────────────
  const nameInput = document.getElementById('ws-name');
  const pathInput = document.getElementById('ws-path');
  let pathManuallyEdited = false;

  pathInput.addEventListener('input', () => {
    pathManuallyEdited = true;
  });

  nameInput.addEventListener('input', () => {
    if (!pathManuallyEdited) {
      const slug = nameInput.value.trim().toLowerCase().replace(/\s+/g, '-');
      pathInput.value = slug ? `~/WorkingProjects/${slug}` : '';
    }
  });

  // ── Folder picker ───────────────────────────────────────────────────────────
  async function pickFolder(inputId, btnId) {
    const input = document.getElementById(inputId);
    const btn = document.getElementById(btnId);
    const originalLabel = btn.textContent;
    btn.disabled = true;
    btn.textContent = '...';
    try {
      const res = await fetch('/pick-folder');
      const data = await res.json();
      if (data.path) {
        input.value = data.path;
        // If user picked workspace path via Browse, mark as manually edited
        if (inputId === 'ws-path') pathManuallyEdited = true;
      }
    } catch (_) {
      // Network error — silently ignore, button re-enables below
    } finally {
      btn.disabled = false;
      btn.textContent = originalLabel;
    }
  }
</script>
{% endblock %}
```

**Step 2: Manual test**

1. Open `http://localhost:8899/new`
2. Type "My Project" in Name → verify `workspace_path` auto-fills to `~/WorkingProjects/my-project`
3. Edit `workspace_path` manually → type another name → verify it no longer auto-updates
4. Click "Browse..." beside Workspace directory → macOS dialog appears → select a folder → input fills with path
5. Click "Browse..." beside Initial directory → same behavior
6. Submit the form → workspace created successfully

**Step 3: Commit**

```bash
git add web/templates/new.html
git commit -m "feat(web): auto-fill workspace path from name, add Browse buttons to new workspace form"
```

---

### Task 3: Update `workspace.html` — Browse button for Add directory

**Files:**
- Modify: `web/templates/workspace.html` (the Add dir form section, lines 72-88)

**Goal:** Add "Browse..." button beside the `path` input in the Add directory form.

**Step 1: Replace the Add dir form section**

Find this block in `workspace.html` (around line 72-88):

```html
  <!-- Add dir form (HTMX) -->
  <form hx-post="/workspace/{{ ws.name | urlencode }}/add-dir"
        hx-target="#dir-list"
        hx-swap="innerHTML"
        class="flex gap-2">
    <input type="text" name="path"
           placeholder="/path/to/repo"
           class="flex-1 bg-gray-800 border border-gray-700 text-gray-200 text-sm rounded px-3 py-1.5 focus:outline-none focus:border-orange-500">
    <input type="text" name="role"
           placeholder="Role (optional)"
           class="w-36 bg-gray-800 border border-gray-700 text-gray-200 text-sm rounded px-3 py-1.5 focus:outline-none focus:border-orange-500">
    <button type="submit"
            class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-1.5 rounded transition-colors">
      Add
    </button>
  </form>
```

Replace it with:

```html
  <!-- Add dir form (HTMX) -->
  <form hx-post="/workspace/{{ ws.name | urlencode }}/add-dir"
        hx-target="#dir-list"
        hx-swap="innerHTML"
        class="flex gap-2">
    <input type="text" id="add-dir-path" name="path"
           placeholder="/path/to/repo"
           class="flex-1 bg-gray-800 border border-gray-700 text-gray-200 text-sm rounded px-3 py-1.5 focus:outline-none focus:border-orange-500">
    <button type="button" id="browse-add-dir"
            onclick="pickFolder('add-dir-path', 'browse-add-dir')"
            class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-1.5 rounded transition-colors whitespace-nowrap">
      Browse...
    </button>
    <input type="text" name="role"
           placeholder="Role (optional)"
           class="w-36 bg-gray-800 border border-gray-700 text-gray-200 text-sm rounded px-3 py-1.5 focus:outline-none focus:border-orange-500">
    <button type="submit"
            class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-1.5 rounded transition-colors">
      Add
    </button>
  </form>

  <script>
    async function pickFolder(inputId, btnId) {
      const input = document.getElementById(inputId);
      const btn = document.getElementById(btnId);
      const originalLabel = btn.textContent;
      btn.disabled = true;
      btn.textContent = '...';
      try {
        const res = await fetch('/pick-folder');
        const data = await res.json();
        if (data.path) input.value = data.path;
      } catch (_) {
        // Silently ignore network errors
      } finally {
        btn.disabled = false;
        btn.textContent = originalLabel;
      }
    }
  </script>
```

**Step 2: Manual test**

1. Open any workspace detail page (e.g., `http://localhost:8899/workspace/MyProject`)
2. Click "Browse..." beside the path input → macOS folder dialog appears
3. Select a folder → path input fills with the selected path
4. Fill in Role (optional) → click "Add" → directory appears in the list

**Step 3: Commit**

```bash
git add web/templates/workspace.html
git commit -m "feat(web): add Browse button to add-dir form in workspace detail"
```

---

### Task 4: Final integration test

**Step 1: Full end-to-end test**

1. Start the server: `cw web`
2. Open `http://localhost:8899`
3. Click "+ New Workspace"
4. Type name → verify path auto-fills
5. Click Browse for workspace path → select folder → verify path updates and auto-fill disabled
6. Click Browse for initial dir → select folder → verify path fills
7. Submit → workspace created
8. On workspace detail page → click Browse for add-dir → select folder → add → verify in list
9. Launch workspace → Terminal opens

**Step 2: Edge case verification**

- Cancel the folder picker dialog → input unchanged, button re-enables
- Clear the Name field after typing → workspace_path clears (if not manually edited)
- Submit form with Browse-selected paths → paths correctly saved

**Step 3: Final commit if any fixes needed**

```bash
git add -p  # stage only relevant changes
git commit -m "fix(web): <description of any fixes>"
```
