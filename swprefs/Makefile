TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = swprefs

swprefs_FILES = SWPRootListController.m ../SWBackgroundCache.m
swprefs_FRAMEWORKS = UIKit ImageIO CoreGraphics
swprefs_PRIVATE_FRAMEWORKS = Preferences
swprefs_INSTALL_PATH = /Library/PreferenceBundles
swprefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# Version shown in the settings header, taken from control. Not named
# PACKAGE_VERSION: theos uses that in package.mk for the deb's own version.
SWP_VERSION := $(shell sed -n 's/^Version: //p' $(THEOS_PROJECT_DIR)/control)
ifeq ($(SWP_VERSION),)
$(error no Version line in $(THEOS_PROJECT_DIR)/control)
endif
swprefs_CFLAGS += -DPACKAGE_VERSION='"$(SWP_VERSION)"'

include $(THEOS_MAKE_PATH)/bundle.mk
swprefs_FRAMEWORKS += PhotosUI
