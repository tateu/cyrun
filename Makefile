export GO_EASY_ON_ME = 1

export ARCHS = arm64
export SDKVERSION = 8.4
export TARGET = iphone:clang:8.4

# export DEBUG = 1
ifeq ($(DEBUG),1)
	PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)+debug
else
	PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = cyrun2
cyrun2_FILES = main.mm
cyrun2_FRAMEWORKS = MobileCoreServices
cyrun2_PRIVATE_FRAMEWORKS = BackBoardServices SoftwareUpdateServices
cyrun2_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
