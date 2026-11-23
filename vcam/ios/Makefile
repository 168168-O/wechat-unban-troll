TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = Weixin SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = vcam
vcam_FILES = Tweak.xm ActionStore.m ActionServer.m ControlPanel.m Stealth.m JBHide.xm vendor/fishhook.c
vcam_CFLAGS = -fobjc-arc
vcam_CFLAGS += -Ivendor
vcam_FRAMEWORKS = AVFoundation CoreMedia CoreVideo UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

# rootless 越狱（Dopamine / palera1n rootless）：make package THEOS_PACKAGE_SCHEME=rootless
# roothide 越狱（Bootstrap）：            make package THEOS_PACKAGE_SCHEME=roothide
# 老 rootful（unc0ver / checkra1n）：      直接 make package
