#!/usr/bin/env bash
# Reaplica o projeto inteiro (CLI, systemd service, regra udev e widget da
# barra) a partir desta pasta. Seguro rodar quantas vezes quiser.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="local.haste2-rgb"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "== CLI + service + udev =="
"$ROOT/install.sh"

echo
echo "== Widget da barra (Quickshell) =="
mkdir -p "$PLUGIN_DIR"
cp "$ROOT/manifest.json" "$ROOT/BarWidget.qml" "$ROOT/Panel.qml" "$PLUGIN_DIR/"

# rescanPlugins nem sempre repropaga um plugin novo/alterado a tempo do
# "enable" seguinte enxergar — restart completo do shell é o que
# confiavelmente funciona.
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell || true
  sleep 2
elif command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins || true
  sleep 1
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable "$PLUGIN_ID" || true
fi

echo
echo "Pronto. Se o ícone ainda não aparecer, rode manualmente:"
echo "  omarchy-restart-shell && omarchy plugin enable $PLUGIN_ID"
