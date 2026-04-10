APP_NAME = Markdown Viewer
BUNDLE_NAME = Markdown Viewer.app
EXECUTABLE = MarkdownViewer
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(BUILD_DIR)/$(BUNDLE_NAME)
INSTALL_DIR = /Applications
PLIST = Sources/MarkdownViewer/Info.plist
ICNS  = Sources/MarkdownViewer/AppIcon.icns
DMG_NAME = MarkdownViewer.dmg
DMG_PATH = $(BUILD_DIR)/$(DMG_NAME)
DMG_VOLUME = Markdown Viewer
DMG_BG_SCRIPT = scripts/create-dmg-background.swift
DMG_WINDOW_W = 660
DMG_WINDOW_H = 400

.PHONY: build release run clean install uninstall bundle dmg

# Debug build
build:
	swift build

# Release build (optimized)
release:
	swift build -c release

# Build .app bundle
bundle: release
	@echo "→ Creating $(BUNDLE_NAME)..."
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(RELEASE_DIR)/$(EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(EXECUTABLE)"
	@cp "$(PLIST)" "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "$(ICNS)"  "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@echo "APPL????" > "$(APP_BUNDLE)/Contents/PkgInfo"
	@echo "✓ $(BUNDLE_NAME) criado em $(BUILD_DIR)/"

# Create distributable DMG
dmg: bundle
	@bash scripts/create-dmg.sh "$(APP_BUNDLE)" "$(DMG_PATH)" "$(DMG_BG_SCRIPT)"

# Run debug build
run: build
	"$(BUILD_DIR)/debug/$(EXECUTABLE)"

# Run release build
run-release: bundle
	open "$(APP_BUNDLE)"

# Install to /Applications
install: bundle
	@echo "→ Instalando em $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@echo "✓ $(BUNDLE_NAME) instalado em $(INSTALL_DIR)/"

# Uninstall from /Applications
uninstall:
	@echo "→ Removendo $(INSTALL_DIR)/$(BUNDLE_NAME)..."
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@echo "✓ Removido"

# Clean build artifacts
clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)" "$(DMG_PATH)"
	@echo "✓ Limpo"

# Show help
help:
	@echo ""
	@echo "  Markdown Viewer"
	@echo "  ───────────────────────────────"
	@echo "  make build       Build (debug)"
	@echo "  make release     Build (release)"
	@echo "  make bundle      Criar .app bundle"
	@echo "  make dmg         Criar DMG distribuível"
	@echo "  make run         Build e executar (debug)"
	@echo "  make run-release Build e executar (release)"
	@echo "  make install     Instalar em /Applications"
	@echo "  make uninstall   Remover de /Applications"
	@echo "  make clean       Limpar artifacts"
	@echo ""
