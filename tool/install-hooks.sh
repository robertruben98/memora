#!/usr/bin/env bash
# Instala los git hooks compartidos del repo (tool/hooks/ -> .git/hooks/).
# Uso:
#   ./tool/install-hooks.sh           # symlink; si ya hay hook custom, avisa.
#   ./tool/install-hooks.sh --force   # sobreescribe sin preguntar.

set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE=1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: no estas dentro de un repo git." >&2
  exit 1
fi

SRC_DIR="$REPO_ROOT/tool/hooks"
GIT_HOOKS_DIR="$(git rev-parse --git-path hooks)"
mkdir -p "$GIT_HOOKS_DIR"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: $SRC_DIR no existe." >&2
  exit 1
fi

installed=0
skipped=0
for hook_src in "$SRC_DIR"/*; do
  [[ -f "$hook_src" ]] || continue
  name="$(basename "$hook_src")"
  dest="$GIT_HOOKS_DIR/$name"

  chmod +x "$hook_src" || true

  if [[ -e "$dest" || -L "$dest" ]]; then
    # ya apunta al mismo source?
    if [[ -L "$dest" && "$(readlink "$dest")" == "$hook_src" ]]; then
      echo "[install-hooks] $name -> ya instalado (symlink correcto)"
      continue
    fi
    if [[ $FORCE -eq 0 ]]; then
      echo "[install-hooks] AVISO: $dest ya existe (hook custom). Usa --force para sobreescribir."
      skipped=$((skipped + 1))
      continue
    fi
    rm -f "$dest"
  fi

  ln -s "$hook_src" "$dest"
  echo "[install-hooks] $name -> instalado (symlink)"
  installed=$((installed + 1))
done

echo ""
echo "[install-hooks] resumen: $installed instalado(s), $skipped omitido(s)."
echo "[install-hooks] bypass emergencia: SKIP_HOOKS=1 git commit ..."
