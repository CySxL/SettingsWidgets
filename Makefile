export THEOS_PACKAGE_SCHEME=rootless
export TARGET = iphone:clang:16.5:14.0
export ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = Preferences BluetoothManager

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SettingsWidgets

SettingsWidgets_FILES = $(wildcard *.m) Tweak.xm
SettingsWidgets_CFLAGS = -fobjc-arc -O3
SettingsWidgets_FRAMEWORKS = Foundation UIKit IOKit ImageIO CoreGraphics
SettingsWidgets_PRIVATE_FRAMEWORKS = FrontBoardServices SpringBoardServices Preferences BluetoothManager

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += swprefs
include $(THEOS_MAKE_PATH)/aggregate.mk


# The version on the settings page. A sed that matches nothing exits 0, so the
# file and the string it rewrites are both checked first: without that, a page
# stuck on an old version is the only symptom and it looks like a real number.
after-stage::
	@VERSION=$$(awk '/^Version:/ {print $$2}' control); \
	PLIST="$(THEOS_STAGING_DIR)/Library/PreferenceBundles/swprefs.bundle/Root.plist"; \
	[ -f "$$PLIST" ] || { echo "after-stage: no Root.plist at $$PLIST" >&2; exit 1; }; \
	grep -q 'SettingsWidgets v' "$$PLIST" || { echo "after-stage: no version string in $$PLIST" >&2; exit 1; }; \
	sed -i '' -E "s/SettingsWidgets v[0-9.]+/SettingsWidgets v$$VERSION/g" "$$PLIST"
