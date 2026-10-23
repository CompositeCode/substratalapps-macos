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

test: ## SubstratalKit unit tests
	cd Packages/SubstratalKit && swift test

ui-test: project ## UI smoke tests (needs Accessibility permission for Xcode)
	$(XCODEBUILD) test

sync-api: ## Vendor the latest openapi.yaml from the API repo's main
	scripts/sync-openapi.sh

sync-screens: ## Re-import the screen catalog from ../substratalapps-applications-specs
	ruby scripts/import-screens.rb

help-build: ## Build the Help Center locally and check its links
	ruby scripts/help-generate.rb
	cd help && bundle install --quiet && bundle exec jekyll build
	ruby scripts/help-check.rb help/_site

help-serve: ## Serve the Help Center at http://localhost:4000/substratalapps-macos/
	ruby scripts/help-generate.rb
	cd help && bundle install --quiet && bundle exec jekyll serve --livereload

check: test build help-build ## Everything CI runs

.PHONY: help project build run test ui-test sync-api sync-screens help-build help-serve check
