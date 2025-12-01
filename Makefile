export THEOS = $(HOME)/theos
export ARCHS = armv7 arm64
export TARGET = iphone:clang:16.5:9.3

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = HomeButler

HomeButler_FILES = HomeButler/main.m \
	HomeButler/AppDelegate.m \
	HomeButler/Models/HAEntity.m \
	HomeButler/Models/HBRoom.m \
	HomeButler/API/HAAPIClient.m \
	HomeButler/API/HBBatteryReporter.m \
	HomeButler/Theme/HBThemeManager.m \
	HomeButler/Views/EntityCell.m \
	HomeButler/Views/HBRoomCell.m \
	HomeButler/Views/HBLightToggleCell.m \
	HomeButler/Views/HBIconView.m \
	HomeButler/Views/HBActionButton.m \
	HomeButler/ViewControllers/DashboardViewController.m \
	HomeButler/ViewControllers/HBDashboardViewController.m \
	HomeButler/ViewControllers/HBRoomDetailViewController.m \
	HomeButler/ViewControllers/HBAddRoomViewController.m \
	HomeButler/ViewControllers/CameraViewController.m \
	HomeButler/ViewControllers/SettingsViewController.m \
	HomeButler/ViewControllers/LightControlViewController.m

HomeButler_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

HomeButler_CFLAGS = -fobjc-arc -fno-modules -Wno-deprecated-module-dot-map -Wno-nullability-completeness -Wno-nullability -IHomeButler -IHomeButler/API -IHomeButler/Models -IHomeButler/Views -IHomeButler/ViewControllers -IHomeButler/Theme
HomeButler_USE_MODULES = 0

include $(THEOS_MAKE_PATH)/application.mk
