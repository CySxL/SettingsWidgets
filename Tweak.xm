#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "SWWidgetContainerView.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

extern "C"
int __isOSVersionAtLeast(int major, int minor, int patch) {
	NSOperatingSystemVersion version;
	version.majorVersion = major;
	version.minorVersion = minor;
	version.patchVersion = patch;
	return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

#define MIN_WIDGET_HEIGHT 100

@interface UITraitCollection (iOS13)
+(UITraitCollection *)currentTraitCollection;
@end

@interface SWWidgetContainerView (CustomBackground)
-(void)setupWidgetsWithType1:(int)w1 type2:(int)w2 type3:(int)w3 type4:(int)w4 widgetInset:(int)inset cornerRadius:(int)cr fontColor1:(int)fc1 fontColor2:(int)fc2 fontColor3:(int)fc3 fontColor4:(int)fc4;
-(void)applyCustomBackgrounds;
@end

static id getPref(NSString *key) {
	return (id)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.shepgoba.swprefs")));
}

// A plist can hold anything, so check the type before asking for a value.
static BOOL isNumberLike(id value) {
	return [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]];
}

static BOOL boolForKey(NSString *key, BOOL fallBack) {
	id result = getPref(key);
	return isNumberLike(result) ? [result boolValue] : fallBack;
}

static int intForKey(NSString *key, int fallBack) {
	id result = getPref(key);
	return isNumberLike(result) ? [result intValue] : fallBack;
}

static BOOL enabled;
static BOOL widget2Enabled, widget3Enabled, widget4Enabled;
static int widgetCornerRadius, widgetHeight, widgetInset;
static int widgetType1, widgetType2, widgetType3, widgetType4;
static int fontColor1, fontColor2, fontColor3, fontColor4;

static void loadPrefs() {
	CFPreferencesAppSynchronize(CFSTR("com.shepgoba.swprefs"));

  	enabled = boolForKey(@"enabled", YES);

	widgetHeight = intForKey(@"widgetHeight", 120);
	widgetInset = intForKey(@"widgetInset", 15);
	widgetCornerRadius = intForKey(@"widgetCornerRadius", 16);

    widgetType1 = intForKey(@"widgetType1", 0);
    widget2Enabled = boolForKey(@"widget2Enabled", YES);
	widgetType2 = intForKey(@"widgetType2", 1);
    widget3Enabled = boolForKey(@"widget3Enabled", NO);
    widgetType3 = intForKey(@"widgetType3", 2);
    widget4Enabled = boolForKey(@"widget4Enabled", NO);
    widgetType4 = intForKey(@"widgetType4", 3);

    fontColor1 = intForKey(@"fontColor1", 2);
    fontColor2 = intForKey(@"fontColor2", 2);
    fontColor3 = intForKey(@"fontColor3", 2);
    fontColor4 = intForKey(@"fontColor4", 2);
}

@interface PSUIPrefsListController : PSListController
@property (nonatomic, retain) SWWidgetContainerView *widgetContainerView;
- (id)specifierForID;
@end

%group Tweak
%hook PSUIPrefsListController
%property (nonatomic, retain) SWWidgetContainerView *widgetContainerView;
-(void)viewWillAppear:(BOOL)arg1 {
	%orig;
	UITableView *tblView = self.table;
    
    int activeRows = 0;
    if (widgetType1 != 99 || (widget2Enabled && widgetType2 != 99)) activeRows++;
    if ((widget3Enabled && widgetType3 != 99) || (widget4Enabled && widgetType4 != 99)) activeRows++;
    CGFloat singleHeight = widgetHeight < MIN_WIDGET_HEIGHT ? MIN_WIDGET_HEIGHT : widgetHeight;
    CGFloat totalHeight = singleHeight * (activeRows > 0 ? activeRows : 1);
    
	self.widgetContainerView.frame = CGRectMake(0, 0, tblView.frame.size.width, totalHeight);
}
-(void)viewDidLoad {
	%orig;
	UITableView *tblView = self.table;

	self.widgetContainerView = [[SWWidgetContainerView alloc] init];
	self.widgetContainerView.backgroundColor = UIColor.clearColor;
	tblView.tableHeaderView = self.widgetContainerView;

    int w2 = widget2Enabled ? widgetType2 : 99;
    int w3 = widget3Enabled ? widgetType3 : 99;
    int w4 = widget4Enabled ? widgetType4 : 99;

	[self.widgetContainerView setupWidgetsWithType1:widgetType1 type2:w2 type3:w3 type4:w4 widgetInset:widgetInset cornerRadius:widgetCornerRadius fontColor1:fontColor1 fontColor2:fontColor2 fontColor3:fontColor3 fontColor4:fontColor4];
	[self.widgetContainerView setWidgetBackgrounds];

    [self.widgetContainerView applyCustomBackgrounds];
}
-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
	%orig;
	[self.widgetContainerView setWidgetBackgrounds];
}
%end
%end

%ctor {
	loadPrefs();
	if (enabled) %init(Tweak);
}
