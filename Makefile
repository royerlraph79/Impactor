ID := dev.khcrysalis.PlumeImpactor

OS := macos
ARCH := arm64
TARGET := aarch64-apple-darwin

PROFILE ?= release
SUFFIX := $(OS)-$(ARCH)

PREFIX ?= /Applications
DIST := dist
TARGET_DIR := target/$(TARGET)/$(PROFILE)

BUNDLE ?= 0

clean:
	@rm -rf ./dist ./build

macos:
	@mkdir -p $(DIST)
	@echo "▶ Building for $(TARGET)..."
	@cargo build --bins --workspace --$(PROFILE) --target $(TARGET)
	@cp $(TARGET_DIR)/plumeimpactor $(DIST)/plumeimpactor-$(SUFFIX)
	@cp $(TARGET_DIR)/plumesign $(DIST)/plumesign-$(SUFFIX)

ifeq ($(BUNDLE),1)
	@echo "▶ Creating .app bundle..."
	@cp -R package/macos/Impactor.app $(DIST)/Impactor.app
	@cp $(DIST)/plumeimpactor-$(SUFFIX) $(DIST)/Impactor.app/Contents/MacOS/Impactor
	@chmod +x $(DIST)/Impactor.app/Contents/MacOS/Impactor
	@strip $(DIST)/Impactor.app/Contents/MacOS/Impactor
	@VERSION=$$(awk '/\[workspace.package\]/,/^$$/' Cargo.toml | sed -nE 's/version *= *"([^"]*)".*/\1/p'); \
		/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$VERSION" $(DIST)/Impactor.app/Contents/Info.plist; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$VERSION" $(DIST)/Impactor.app/Contents/Info.plist
endif

install:
	@cp -r $(DIST)/Impactor.app $(PREFIX)/Impactor.app
