TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = GooglePhotos MobileSlideShow Preferences
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = Gunshot
Gunshot_FILES = Tweak.xm Shared/IPCClient.m Shared/GSSandboxAccess.m Shared/GSDiscovery.c UI/GSPanel.m UI/GSAccountMenu.m UI/GSNativeAccount.m UI/GSExporter.m UI/GSNativeRouting.m UI/GSUploadDiagnostics.m UI/GSUnlimitedStorage.m
Gunshot_CFLAGS = -fobjc-arc -fblocks -IShared
Gunshot_FRAMEWORKS = UIKit Foundation Photos PhotosUI
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Daemon Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
before-all::
	@test -f .build/libgotohp.a || (echo 'Run scripts/build-go.sh first'; exit 1)
after-stage::
	python3 scripts/stage.py "$(THEOS_STAGING_DIR)" "$(THEOS_PACKAGE_INSTALL_PREFIX)"
