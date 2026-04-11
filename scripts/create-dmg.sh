#!/bin/bash
set -euo pipefail

APP_BUNDLE="$1"
DMG_PATH="$2"
DMG_BG_SCRIPT="$3"
VOLUME_NAME="Pendown"
WINDOW_W=660
WINDOW_H=400
STAGING_DIR=".build/dmg-staging"
TMP_DMG=".build/tmp.dmg"

echo "→ Gerando imagem de fundo..."
mkdir -p "$STAGING_DIR/.background"
# Pass the real app icon so it appears in the background canvas
ICON_PATH="$(dirname "$DMG_BG_SCRIPT")/../icone.png"
swift "$DMG_BG_SCRIPT" "$STAGING_DIR/.background/bg.png" "$WINDOW_W" "$WINDOW_H" "$(realpath "$ICON_PATH" 2>/dev/null || echo "")"

echo "→ Preparando conteúdo do DMG..."
rm -rf "$STAGING_DIR/Pendown.app"
cp -R "$APP_BUNDLE" "$STAGING_DIR/Pendown.app"
ln -sf /Applications "$STAGING_DIR/Applications"

echo "→ Criando DMG temporário..."
rm -f "$TMP_DMG" "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$TMP_DMG"

echo "→ Configurando aparência do DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$TMP_DMG" | grep "$VOLUME_NAME" | awk -F'\t' '{print $NF}')
sleep 1

osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, $((200 + WINDOW_W)), $((200 + WINDOW_H))}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set text size of theViewOptions to 13
        set background picture of theViewOptions to file ".background:bg.png"
        set position of item "Pendown.app" of container window to {185, 180}
        set position of item "Applications" of container window to {475, 180}
        close
        open
        update without registering applications
    end tell
end tell
EOF

sync
sleep 2
hdiutil detach "$MOUNT_DIR" -quiet

echo "→ Comprimindo DMG final..."
hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "✓ DMG criado: $DMG_PATH"
echo "  Tamanho: $SIZE"
echo ""
