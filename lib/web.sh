#!/usr/bin/env bash
# web.sh - cw web command: launch local Web UI server

cmd_web() {
  local port="${1:-8765}"
  local cw_web_dir="${CW_WEB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../web" && pwd)}"

  # Check Python 3
  if ! command -v python3 &>/dev/null; then
    error "$(t "web_python_required")"
    exit 1
  fi

  # Create/use virtual environment
  local req_file="$cw_web_dir/requirements.txt"
  local venv_dir="$cw_web_dir/.venv"
  if [[ ! -d "$venv_dir" ]]; then
    info "$(t "web_checking_deps")..."
    python3 -m venv "$venv_dir" || {
      error "$(t "web_pip_failed")"
      exit 1
    }
    "$venv_dir/bin/pip" install -q -r "$req_file" || {
      error "$(t "web_pip_failed")"
      exit 1
    }
  fi

  local url="http://localhost:${port}"
  success "$(t "web_starting") $url"
  echo "  $(dim "$(t "web_stop_hint")")"
  echo ""

  # Open browser (macOS)
  if command -v open &>/dev/null; then
    (sleep 1.5 && open "$url") &
  fi

  # Start uvicorn
  cd "$cw_web_dir"
  exec "$venv_dir/bin/python" -m uvicorn main:app --port "$port" --host 127.0.0.1
}
