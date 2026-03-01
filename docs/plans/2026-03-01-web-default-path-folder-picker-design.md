# Design: Web UI — Default Workspace Path & Folder Picker

**Date**: 2026-03-01
**Status**: Approved

## Overview

Two UX improvements to the `cw web` interface:

1. **Default workspace path**: When creating a new workspace, the `workspace_path` field auto-fills with `~/WorkingProjects/<name>` based on the Name input, matching the behavior of `cw new`.
2. **Folder picker**: A "Browse..." button beside each path input field triggers a macOS native folder selection dialog (via osascript) and populates the input with the selected path.

## Scope

### Files to modify

- `web/main.py` — add `GET /pick-folder` endpoint
- `web/templates/new.html` — auto-fill + Browse buttons for `workspace_path` and `initial_dir`
- `web/templates/workspace.html` — Browse button for the `path` field in the Add directory form

---

## Architecture

### Backend: `/pick-folder` endpoint

Add a `GET /pick-folder` route to FastAPI that:

1. Runs `osascript -e 'choose folder with prompt "Select a folder:"'` via `subprocess.run`
2. If the user cancels (non-zero return code), returns `{"path": ""}`
3. Converts the AppleScript alias result to a POSIX path using a second `osascript` call
4. Strips trailing slash
5. Returns `{"path": "/absolute/posix/path"}`

```
GET /pick-folder
→ 200 {"path": "/Users/foo/repos/my-project"}
→ 200 {"path": ""}  (on cancel)
```

### Frontend: Auto-fill (new.html)

- Listen to the `input` event on the `name` field
- On each keystroke, if `workspace_path` has not been manually edited, update it to `~/WorkingProjects/<name>`
- Track "user has manually edited workspace_path" with a boolean flag; set `true` on `input` event for `workspace_path`, reset to `false` on clear
- Name-to-path conversion: lowercase, spaces → hyphens (simple slug)

### Frontend: Browse button

Three locations:
1. `new.html` — beside `workspace_path` input
2. `new.html` — beside `initial_dir` input
3. `workspace.html` — beside `path` input in Add directory form

Behavior on click:
1. Disable button, show spinner (or change label to "...")
2. `fetch('/pick-folder')`
3. On success: populate the adjacent input with `data.path` (if non-empty)
4. Re-enable button, restore label

Layout per field:
```
[  input (flex-1)  ] [ Browse... ]
```

---

## UI Details

### Auto-fill logic (JavaScript)

```javascript
const nameInput = document.getElementById('name');
const pathInput = document.getElementById('workspace_path');
let pathManuallyEdited = false;

pathInput.addEventListener('input', () => { pathManuallyEdited = true; });

nameInput.addEventListener('input', () => {
  if (!pathManuallyEdited) {
    const slug = nameInput.value.trim().toLowerCase().replace(/\s+/g, '-');
    pathInput.value = slug ? `~/WorkingProjects/${slug}` : '';
  }
});
```

### Browse button state

```html
<button type="button" onclick="pickFolder('workspace_path')"
        class="bg-gray-700 hover:bg-gray-600 text-gray-200 text-sm px-3 py-2 rounded transition-colors whitespace-nowrap">
  Browse...
</button>
```

```javascript
async function pickFolder(inputId) {
  const btn = event.currentTarget;
  const input = document.getElementById(inputId);
  btn.disabled = true;
  btn.textContent = '...';
  try {
    const res = await fetch('/pick-folder');
    const data = await res.json();
    if (data.path) input.value = data.path;
  } finally {
    btn.disabled = false;
    btn.textContent = 'Browse...';
  }
}
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| User cancels dialog | Returns `{"path": ""}`, input unchanged |
| osascript not available | Endpoint returns 500, button re-enables silently |
| Network error | `catch` block re-enables button |

---

## Out of Scope

- Path validation (done on form submit, as before)
- Windows/Linux support (osascript is macOS-only; app is already macOS-specific)
- Autocomplete for manual path typing
