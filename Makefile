APP_NAME = Pendown
BUNDLE_NAME = Pendown.app
EXECUTABLE = Pendown
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(BUILD_DIR)/$(BUNDLE_NAME)
INSTALL_DIR = /Applications
PLIST = Sources/Pendown/Info-SPM.plist
ICNS  = Sources/Pendown/AppIcon.icns
ENTITLEMENTS = Sources/Pendown/Pendown.entitlements
DMG_NAME = Pendown.dmg
DMG_PATH = $(BUILD_DIR)/$(DMG_NAME)
DMG_VOLUME = Pendown
DMG_BG_SCRIPT = scripts/create-dmg-background.swift
DMG_WINDOW_W = 660
DMG_WINDOW_H = 400

.PHONY: build release run clean install uninstall bundle dmg xcode help

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
	@echo "✓ $(BUNDLE_NAME) created in $(BUILD_DIR)/"

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
	@echo "→ Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@echo "✓ $(BUNDLE_NAME) installed in $(INSTALL_DIR)/"

# Uninstall from /Applications
uninstall:
	@echo "→ Removing $(INSTALL_DIR)/$(BUNDLE_NAME)..."
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE_NAME)"
	@echo "✓ Removed"

# Generate Xcode project (requires xcodegen)
xcode:
	@command -v xcodegen >/dev/null 2>&1 || { echo "Error: xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "✓ Pendown.xcodeproj generated — open in Xcode to configure signing"

# Clean build artifacts
clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)" "$(DMG_PATH)"
	@echo "✓ Clean"

# Show help
help:
	@echo ""
	@echo "  Pendown — Markdown editor & viewer"
	@echo "  ───────────────────────────────────"
	@echo "  make build       Build (debug)"
	@echo "  make release     Build (release)"
	@echo "  make bundle      Create .app bundle"
	@echo "  make dmg         Create distributable DMG"
	@echo "  make run         Build and run (debug)"
	@echo "  make run-release Build and run (release)"
	@echo "  make install     Install to /Applications"
	@echo "  make uninstall   Remove from /Applications"
	@echo "  make xcode       Generate Xcode project"
	@echo "  make clean       Clean artifacts"
	@echo ""
