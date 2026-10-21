TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeychainClear
KeychainClear_FILES = Tweak.xm
KeychainClear_CFLAGS = -fobjc-arc
KeychainClear_FRAMEWORKS = Foundation Security

# Replace with the target app bundle identifier.
KeychainClear_FILTER = com.xxxx

include $(THEOS_MAKE_PATH)/tweak.mk
