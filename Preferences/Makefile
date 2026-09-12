include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = GunshotPrefs
GunshotPrefs_FILES = RootListController.m ../Shared/IPCClient.m ../UI/GSPanel.m ../UI/GSExporter.m ../UI/GSNativeRouting.m ../UI/GSUploadDiagnostics.m
GunshotPrefs_CFLAGS = -fobjc-arc -I../Shared
GunshotPrefs_FRAMEWORKS = UIKit Foundation Photos PhotosUI
GunshotPrefs_PRIVATE_FRAMEWORKS = Preferences
GunshotPrefs_LDFLAGS = -F$(THEOS_PROJECT_DIR)/BuildSupport
GunshotPrefs_LIBRARIES = rocketbootstrap
GunshotPrefs_INSTALL_PATH = /Library/PreferenceBundles
GunshotPrefs_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/bundle.mk
