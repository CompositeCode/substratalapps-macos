# Day-to-day commands. `make help` lists them.
.DEFAULT_GOAL := help
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Substratal\ Hub.app
XCODEBUILD := xcodebuild -project SubstratalHub.xcodeproj -scheme SubstratalHub -configuration Debug \
	-destination 'platform=macOS' -derivedDataPath $(DERIVED) -skipPackagePluginValidation -skipMacroValidation
API ?= https://api.substratalapps.com

help: ## List commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

project: ## Generate SubstratalHub.xcodeproj from project.yml
	xcodegen generate

build: project ## Build the app (Debug)
	$(XCODEBUILD) build

run: build ## Build and run; API=http://localhost:8080 points it at a local devserver
	open $(APP) --args -SubstratalAPIBaseURL $(API)

run-local: ## Build and launch for testing; API=… to choose the API (default production)
	scripts/run-local.sh $(API)

pkg: ## Build the installer into build/pkg (signs/notarizes when APP_IDENTITY etc. are set)
	scripts/build-pkg.sh

dist: ## Build a distributable .pkg on this Mac, signing/notarizing with what's in your Keychain
	scripts/dist-local.sh --open

test: ## SubstratalKit unit tests
	cd Packages/SubstratalKit && swift test

ui-test: project ## UI smoke tests (needs Accessibility permission for Xcode)
	$(XCODEBUILD) test

sync-api: ## Vendor the latest openapi.yaml from the API repo's main
	scripts/sync-openapi.sh

sync-screens: ## Re-import the screen catalog from ../substratalapps-applications-specs
	ruby scripts/import-screens.rb

SPECS ?= ../substratalapps-applications-specs

help-check: ## Check the app's Help links against a fresh build of the Hub help center in SPECS
	cd $(SPECS) && npm ci --silent && npm run build
	ruby scripts/help-check.rb $(SPECS)/_site/help

check: test build help-check ## Everything CI runs

.PHONY: help project build run run-local pkg dist test ui-test sync-api sync-screens help-check check
