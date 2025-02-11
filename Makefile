ARCHS = arm64

TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatNotification

$(TWEAK_NAME)_FILES = Tweak.xm DynamicIslandSettingViewController.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit UserNotifications
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = 

include $(THEOS_MAKE_PATH)/tweak.mk 