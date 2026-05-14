.PHONY: build probe validate clean

build:
	swift build

probe:
	swift run CodexGaugeProbe

validate:
	plutil -lint CodexGauge/Resources/Info.plist CodexGauge.xcodeproj/project.pbxproj
	swift build
	swift run CodexGaugeProbe

clean:
	rm -rf .build
