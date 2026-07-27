TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = swprefs

swprefs_FILES = SWPRootListController.m
swprefs_FRAMEWORKS = UIKit
swprefs_PRIVATE_FRAMEWORKS = Preferences
swprefs_INSTALL_PATH = /Library/PreferenceBundles
swprefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
swprefs_CFLAGS += -DTWEAK_VERSION=\"$(shell awk '/Version:/ {print $$2}' ../control)\"
swprefs_FRAMEWORKS += PhotosUI
