#!/usr/bin/env bash
# lang.sh - cw lang command

cmd_lang() {
  local new_lang="${1:-}"

  if [[ -z "$new_lang" ]]; then
    # Show current language
    local current
    current=$(cw_lang)
    echo ""
    echo "$(bold "Current language: $current")"
    echo ""
    echo "  Usage: cw lang [en|ja]"
    echo ""
    echo "  Available languages:"
    echo "    en  - English (default)"
    echo "    ja  - 日本語"
    echo ""
    return
  fi

  if [[ "$new_lang" != "en" && "$new_lang" != "ja" ]]; then
    error "Unsupported language: $new_lang"
    echo "  Supported: en, ja"
    exit 1
  fi

  cw_set_lang "$new_lang"
  success "Language changed to: $new_lang"
}
