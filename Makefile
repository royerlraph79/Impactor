ID := dev.khcrysalis.PlumeImpactor

ifeq ($(OS),Windows_NT)
OS := windows
ARCH ?= x86_64
else
ARCH ?= $(shell uname -m)
ifeq ($(shell uname -s),Linux)
OS := linux
endif
ifeq ($(shell uname -s),Darwin)
OS := macos
endif
endif

PROFILE ?= debug
PREFIX ?= /usr/local
SUFFIX ?= $(OS)-$(ARCH)

BUNDLE ?= 0
BIN1 ?=
BIN2 ?=

APPIMAGE ?= 0
APPIMAGE_APPDIR ?= /tmp/AppDir

NSIS ?= 0

FLATPAK ?= 0
FLATPAK_BUILDER_TOOLS ?= /tmp/flatpak-builder-tools/
FLATPAK_BUILDER_TOOLS_COMMIT ?= 3fc0620788a1dda1a3a539b8f972edadce8260ab
FLATPAK_SHARED_MODULES ?= ./shared-modules/
FLATPAK_SHARED_MODULES_COMMIT ?= d1a2cf59d137b47abc07297ecd35a5af9b5e16f4
FLATPAK_BUILDER_DIR ?= ./.flatpak-out/
FLATPAK_BUILDER_MANIFEST ?= $(ID).json
FLATPAK_BUNDLE_REPO ?= ~/.local/share/flatpak/repo
FLATPAK_BUNDLE_FILENAME ?= Impactor-$(SUFFIX).flatpak
FLATPAK_BUNDLE_NAME ?= $(ID)

clean:
	@rm -rf ./dist
	@rm -rf ./build
	@rm -rf ./.flatpak-builder
	@rm -rf $(FLATPAK_BUILDER_DIR)

# ------------------------
# macOS
# ------------------------

macos:
	@mkdir -p dist

ifeq ($(and $(BIN1),$(BIN2)),)
ifeq ($(PROFILE),release)
	@cargo build --bins --workspace --release
else
	@cargo build --bins --workspace
endif
	@cp target/$(PROFILE)/plumeimpactor dist/plumeimpactor-$(SUFFIX)
	@cp target/$(PROFILE)/plumesign dist/plumesign-$(SUFFIX)
else
	@name=$$(basename $(BIN1)); \
	name=$${name%-$(OS)-*}; \
	lipo -create -output dist/$${name}-$(SUFFIX) $(BIN1) $(BIN2)
endif

ifeq ($(BUNDLE),1)
	@cp -R package/macos/Impactor.app dist/Impactor.app
	@cp dist/plumeimpactor-$(SUFFIX) dist/Impactor.app/Contents/MacOS/Impactor
	@chmod +x dist/Impactor.app/Contents/MacOS/Impactor
	@strip dist/Impactor.app/Contents/MacOS/Impactor
	@VERSION=$$(awk '/\[workspace.package\]/,/^$$/' Cargo.toml | sed -nE 's/version *= *"([^"]*)".*/\1/p'); \
		/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$VERSION" ./dist/Impactor.app/Contents/Info.plist; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$VERSION" ./dist/Impactor.app/Contents/Info.plist
endif

# ------------------------
# Linux
# ------------------------

linux:
ifeq ($(FLATPAK),1)
ifeq ($(wildcard $(FLATPAK_BUILDER_TOOLS)),)
	@git clone https://github.com/flatpak/flatpak-builder-tools.git "$(FLATPAK_BUILDER_TOOLS)"
	@cd $(FLATPAK_BUILDER_TOOLS); git checkout $(FLATPAK_BUILDER_TOOLS_COMMIT)
endif
ifeq ($(wildcard $(FLATPAK_SHARED_MODULES)),)
	@git clone https://github.com/flathub/shared-modules.git "$(FLATPAK_SHARED_MODULES)"
	@cd $(FLATPAK_SHARED_MODULES); git checkout $(FLATPAK_SHARED_MODULES_COMMIT)
endif
	@poetry --project "$(FLATPAK_BUILDER_TOOLS)/cargo" install
	@poetry --project "$(FLATPAK_BUILDER_TOOLS)/cargo" run \
		python "$(FLATPAK_BUILDER_TOOLS)/cargo/flatpak-cargo-generator.py" Cargo.lock -o package/linux/cargo-sources.json
	@flatpak-builder --ccache --force-clean --user --install $(FLATPAK_BUILDER_DIR) "package/linux/$(FLATPAK_BUILDER_MANIFEST)"
	@mkdir -p dist
	@cd package/linux; flatpak build-bundle $(FLATPAK_BUNDLE_REPO) $(FLATPAK_BUNDLE_FILENAME) $(FLATPAK_BUNDLE_NAME)
	@cp package/linux/$(FLATPAK_BUNDLE_FILENAME) ./dist/$(FLATPAK_BUNDLE_FILENAME)
	@rm package/linux/$(FLATPAK_BUNDLE_FILENAME)
endif

ifeq ($(PROFILE),release)
	@cargo build --bins --workspace --release
else
	@cargo build --bins --workspace
endif

	@mkdir -p dist
	@cp target/$(PROFILE)/plumeimpactor ./dist/Impactor-$(SUFFIX)
	@cp target/$(PROFILE)/plumesign ./dist/plumesign-$(SUFFIX)
	@strip dist/Impactor-$(SUFFIX)

# ------------------------
# Windows
# ------------------------

windows:
ifeq ($(PROFILE),release)
	@cargo build --bins --workspace --release
else
	@cargo build --bins --workspace
endif

	@mkdir -p dist
	@mkdir -p dist/nsis
	@cp target/$(PROFILE)/plumesign.exe dist/plumesign-$(SUFFIX).exe
	@cp target/$(PROFILE)/plumeimpactor.exe dist/Impactor-$(SUFFIX)-portable.exe

ifeq ($(NSIS),1)
	@cp target/$(PROFILE)/plumeimpactor.exe dist/nsis/
	@cp -r package/windows/* dist/nsis/
	@makensis dist/nsis/installer.nsi
	@mv dist/nsis/installer.exe dist/Impactor-$(SUFFIX)-setup.exe
endif

# ------------------------
# Install
# ------------------------

install:
ifeq ($(OS),linux)
	@install -Dm755 target/$(PROFILE)/plumesign $(PREFIX)/bin/plumesign
	@install -Dm755 target/$(PROFILE)/plumeimpactor $(PREFIX)/bin/plumeimpactor
	@install -Dm644 package/linux/$(ID).desktop $(PREFIX)/share/applications/$(ID).desktop
	@install -Dm644 package/linux/$(ID).metainfo.xml $(PREFIX)/share/metainfo/$(ID).metainfo.xml
endif

ifeq ($(OS),macos)
	@cp -r ./dist/Impactor.app $(PREFIX)/Impactor.app
endif
