.PHONY: build probe validate test clean resolve

resolve:
	swift package resolve

build:
	swift build

probe:
	swift run CodexGaugeProbe

test:
	swift test

validate:
	plutil -lint CodexGauge/Resources/Info.plist CodexGauge.xcodeproj/project.pbxproj
	swift package resolve
	swift build
	swift run CodexGaugeProbe

clean:
	rm -rf .build
