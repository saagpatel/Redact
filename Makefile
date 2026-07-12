.PHONY: generate build test release archive clean

PROJECT := Redact.xcodeproj
SCHEME := Redact
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro

generate:
	xcodegen generate

build: generate
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO

test: generate
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO

release: generate
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

archive: generate
	xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=iOS' -archivePath build/Redact.xcarchive CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf build
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
