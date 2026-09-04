#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"

install -m 755 "$ROOT/haste2-rgb" "$HOME/.local/bin/haste2-rgb"
install -m 644 "$ROOT/haste2-rgb.service" "$HOME/.config/systemd/user/haste2-rgb.service"
install -m 755 "$ROOT/haste2-dpi-watcher" "$HOME/.local/bin/haste2-dpi-watcher"
install -m 644 "$ROOT/haste2-dpi-watcher.service" "$HOME/.config/systemd/user/haste2-dpi-watcher.service"

echo "Instalando regra udev (vai pedir sua senha de sudo)..."
sudo install -m 644 "$ROOT/99-haste2-rgb.rules" /etc/udev/rules.d/99-haste2-rgb.rules
sudo udevadm control --reload-rules
# --action=add é essencial: "trigger" sem isso manda um evento "change",
# e nossa regra só bate em ACTION=="add" — sem isso a permissão nunca
# é reaplicada num dispositivo já conectado.
sudo udevadm trigger --action=add --subsystem-match=hidraw

systemctl --user daemon-reload
systemctl --user reset-failed haste2-rgb.service 2>/dev/null || true
systemctl --user reset-failed haste2-dpi-watcher.service 2>/dev/null || true
systemctl --user enable --now haste2-rgb.service
systemctl --user enable --now haste2-dpi-watcher.service

echo
echo "Instalado!"
echo
echo "Exemplos:"
echo "  haste2-rgb set purple"
echo "  haste2-rgb set red"
echo "  haste2-rgb set '#8a2be2'"
echo "  haste2-rgb set off"
echo
echo "Status:"
echo "  haste2-rgb status"
