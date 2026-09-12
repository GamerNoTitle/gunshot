TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = GooglePhotos MobileSlideShow Preferences
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = Gunshot
Gunshot_FILES = Tweak.xm Shared/IPCClient.m UI/GSPanel.m UI/GSExporter.m
Gunshot_CFLAGS = -fobjc-arc -IShared
Gunshot_FRAMEWORKS = UIKit Foundation Photos PhotosUI
Gunshot_LIBRARIES = rocketbootstrap
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Daemon Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
before-all::
	@test -f .build/libgotohp.a || (echo 'Run scripts/build-go.sh first'; exit 1)
after-stage::
	python3 scripts/stage.py "$(THEOS_STAGING_DIR)" "$(THEOS_PACKAGE_INSTALL_PREFIX)"
