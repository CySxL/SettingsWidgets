#import "SWWidgetContainerView.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <stdint.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <roothide.h>

@interface UIColor (ios13)
+(id)systemBackgroundColor;
+(id)secondarySystemBackgroundColor;
+(id)tableCellGroupedBackgroundColor;
@end

@interface CALayer (Undocumented)
@property (assign) BOOL continuousCorners;
@end

@interface STStorageDiskMonitor : NSObject
+(id)sharedMonitor;
-(void)updateDiskSpace;
-(uint64_t)deviceSize;
-(uint64_t)lastFree;
-(id)storageSpace;
@end

@interface BatteryHealthUIController : NSObject
-(NSString *)getChargeCapacityRemaining;
-(void)updateData;
@end

@interface CTDataUsage_Decl : NSObject
-(unsigned long long)cellularHome;
-(unsigned long long)cellularRoaming;
@end

@interface CTDeviceDataUsage_Decl : NSObject
-(id)totalDataUsageForPeriod:(unsigned long long)arg1;
-(id)totalDataUsedForPeriod:(unsigned long long)arg1;
-(NSArray *)appDataUsageForPeriod:(unsigned long long)arg1;
-(NSArray *)systemServiceDataUsageForPeriod:(unsigned long long)arg1;
-(NSArray *)uninstalledAppDataUsageForPeriod:(unsigned long long)arg1;
@end

@interface CoreTelephonyClient_Decl : NSObject
-(id)initWithQueue:(dispatch_queue_t)arg1;
-(void)dataUsageForLastPeriods:(unsigned long long)arg1 completion:(void (^)(id, NSError *))arg2;
@end

@interface UIView (CustomBackground)
-(void)setCustomBackgroundImageWithPath:(NSString *)path;
-(void)applyFontColorStyle:(NSInteger)style;
@end

@interface SWWidgetContainerView () {
    UIView *_widgetView3;
    UIView *_widgetView4;
    int _widgetType3;
    int _widgetType4;
    id _btManager;
    BOOL _btObserving;
}
@end

static id getPref(NSString *key) {
    return (id)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.shepgoba.swprefs")));
}

// A plist can hold anything, so check the type before asking for a value.
static BOOL getBoolPref(NSString *key, BOOL defaultVal) {
    id val = getPref(key);
    if (![val isKindOfClass:[NSNumber class]] && ![val isKindOfClass:[NSString class]]) return defaultVal;
    return [val boolValue];
}

static NSString *getIPAddress() {
    NSString *address = @"Wi-Fi Not Connected";
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        struct ifaddrs *temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_INET) {
                if (strcmp(temp_addr->ifa_name, "en0") == 0) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return address;
} 

static unsigned long long extractBytes(id obj) {
    if (!obj) return 0;
    unsigned long long bytes = 0;
    
    if ([obj respondsToSelector:@selector(cellularHome)]) {
        bytes += [(CTDataUsage_Decl *)obj cellularHome];
    } else if ([obj respondsToSelector:NSSelectorFromString(@"_cellularHome")]) {
        bytes += [[obj valueForKey:@"_cellularHome"] unsignedLongLongValue];
    }
    
    if ([obj respondsToSelector:@selector(cellularRoaming)]) {
        bytes += [(CTDataUsage_Decl *)obj cellularRoaming];
    } else if ([obj respondsToSelector:NSSelectorFromString(@"_cellularRoaming")]) {
        bytes += [[obj valueForKey:@"_cellularRoaming"] unsignedLongLongValue];
    }
    
    return bytes;
}

// HotspotPro publishes the list its own Settings pane shows: nickname resolved
// and already filtered to devices it considers present. Reading it rather than
// counting ARP entries here is what stops the two disagreeing. Absent file means
// HotspotPro is not installed, and its switch in the off position writes nothing,
// so both cases have to leave the widget exactly as it was.
static NSArray *hotspotProClients(void) {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:
        jbroot(@"/var/mobile/Library/Preferences/com.dangkhoa.hotspotpro.plist")];
    if (![cfg isKindOfClass:[NSDictionary class]]) return nil;
    id enabled = cfg[@"enabled"];
    if ([enabled respondsToSelector:@selector(boolValue)] && ![enabled boolValue]) return nil;

    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:
        jbroot(@"/var/mobile/Library/Caches/hotspotpro-state.plist")];
    if (![state isKindOfClass:[NSDictionary class]]) return nil;
    id devices = state[@"devicesNow"];
    if (![devices isKindOfClass:[NSArray class]]) return nil;
    return devices;
}

static void accumulateUsage(id ddu, unsigned long long *cellularOut, unsigned long long *hotspotOut) {
    if (!ddu) return;
    if ([ddu isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)ddu enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            accumulateUsage(obj, cellularOut, hotspotOut);
        }];
        return;
    }
    if ([ddu isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)ddu) accumulateUsage(item, cellularOut, hotspotOut);
        return;
    }

    // Cellular: prefer summed per-source usage, fall back to reported total.
    unsigned long long calcTotal = 0;
    if ([ddu respondsToSelector:@selector(appDataUsageForPeriod:)]) {
        NSArray *apps = [(CTDeviceDataUsage_Decl *)ddu appDataUsageForPeriod:0];
        if ([apps isKindOfClass:[NSArray class]]) {
            for (id app in apps) {
                if ([app respondsToSelector:@selector(usage)]) calcTotal += extractBytes([app valueForKey:@"usage"]);
            }
        }
    }
    NSArray *systemServices = nil;
    if ([ddu respondsToSelector:@selector(systemServiceDataUsageForPeriod:)]) {
        id svcs = [(CTDeviceDataUsage_Decl *)ddu systemServiceDataUsageForPeriod:0];
        if ([svcs isKindOfClass:[NSArray class]]) systemServices = (NSArray *)svcs;
    }
    for (id svc in systemServices) {
        if ([svc respondsToSelector:@selector(usage)]) calcTotal += extractBytes([svc valueForKey:@"usage"]);
    }
    if ([ddu respondsToSelector:@selector(uninstalledAppDataUsageForPeriod:)]) {
        NSArray *uapps = [(CTDeviceDataUsage_Decl *)ddu uninstalledAppDataUsageForPeriod:0];
        if ([uapps isKindOfClass:[NSArray class]]) {
            for (id uapp in uapps) {
                if ([uapp respondsToSelector:@selector(usage)]) calcTotal += extractBytes([uapp valueForKey:@"usage"]);
            }
        }
    }
    if (calcTotal > 0) {
        *cellularOut += calcTotal;
    } else {
        id usage = nil;
        if ([ddu respondsToSelector:@selector(totalDataUsageForPeriod:)]) {
            usage = [(CTDeviceDataUsage_Decl *)ddu totalDataUsageForPeriod:0];
        } else if ([ddu respondsToSelector:@selector(totalDataUsedForPeriod:)]) {
            usage = [(CTDeviceDataUsage_Decl *)ddu totalDataUsedForPeriod:0];
        }
        *cellularOut += extractBytes(usage);
    }

    // Hotspot: tethering/hotspot system services only, reusing the fetched list.
    for (id service in systemServices) {
        NSString *bundleId = [service respondsToSelector:@selector(bundleId)] ? [service valueForKey:@"bundleId"] : nil;
        if ([bundleId isKindOfClass:[NSString class]]) {
            if ([bundleId rangeOfString:@"tethering" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleId rangeOfString:@"hotspot" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if ([service respondsToSelector:@selector(usage)]) *hotspotOut += extractBytes([service valueForKey:@"usage"]);
            }
        }
    }
}

@implementation SWWidgetContainerView
-(id)createWidgetViewWithClass:(Class)cls cornerRadius:(int)cornerRadius {
    if (!cls) return nil;
    UIView *view = [[cls alloc] init];
    if (!view) return nil;
    view.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) view.layer.cornerCurve = kCACornerCurveContinuous;
    else view.layer.continuousCorners = YES;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    if ([view respondsToSelector:@selector(openPrefsURL)]) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(openPrefsURL)];
        tap.cancelsTouchesInView = NO;
        [view addGestureRecognizer:tap];
    }
    if ([view respondsToSelector:@selector(setup)]) [(id)view setup];
    return (id)view;
}
-(Class)classForType:(int)type {
    switch (type) {
        case 0: return NSClassFromString(@"SWBatteryWidgetView");
        case 1: return NSClassFromString(@"SWStorageWidgetView");
        case 2: return NSClassFromString(@"SWWifiWidgetView");
        case 3: return NSClassFromString(@"SWCellularWidgetView");
        case 4: return NSClassFromString(@"SWUtilityWidgetView");
        case 5: return NSClassFromString(@"SWHotspotWidgetView");
        case 6: return NSClassFromString(@"SWBluetoothWidgetView");
        default: return Nil;
    }
}
-(void)setupWidgetsWithType1:(int)w1 type2:(int)w2 type3:(int)w3 type4:(int)w4 widgetInset:(int)inset cornerRadius:(int)cr fontColor1:(int)fc1 fontColor2:(int)fc2 fontColor3:(int)fc3 fontColor4:(int)fc4 {
	if (w1 != 99) { _widgetView1 = [self createWidgetViewWithClass:[self classForType:w1] cornerRadius:cr]; if (_widgetView1) [self addSubview:_widgetView1]; else w1 = 99; }
	if (w2 != 99) { _widgetView2 = [self createWidgetViewWithClass:[self classForType:w2] cornerRadius:cr]; if (_widgetView2) [self addSubview:_widgetView2]; else w2 = 99; }
    if (w3 != 99) { _widgetView3 = [self createWidgetViewWithClass:[self classForType:w3] cornerRadius:cr]; if (_widgetView3) [self addSubview:_widgetView3]; else w3 = 99; }
    if (w4 != 99) { _widgetView4 = [self createWidgetViewWithClass:[self classForType:w4] cornerRadius:cr]; if (_widgetView4) [self addSubview:_widgetView4]; else w4 = 99; }

	_widgetType1 = w1; _widgetType2 = w2; _widgetType3 = w3; _widgetType4 = w4;

    if (_widgetView1 && [_widgetView1 respondsToSelector:@selector(applyFontColorStyle:)]) [(id)_widgetView1 applyFontColorStyle:fc1];
    if (_widgetView2 && [_widgetView2 respondsToSelector:@selector(applyFontColorStyle:)]) [(id)_widgetView2 applyFontColorStyle:fc2];
    if (_widgetView3 && [_widgetView3 respondsToSelector:@selector(applyFontColorStyle:)]) [(id)_widgetView3 applyFontColorStyle:fc3];
    if (_widgetView4 && [_widgetView4 respondsToSelector:@selector(applyFontColorStyle:)]) [(id)_widgetView4 applyFontColorStyle:fc4];

    BOOL hasR1 = (w1 != 99 || w2 != 99);
    BOOL hasR2 = (w3 != 99 || w4 != 99);

    if (hasR1) {
        if (w1 != 99 && w2 != 99) {
            [_widgetView1.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset].active = YES;
            [_widgetView1.trailingAnchor constraintEqualToAnchor:self.centerXAnchor constant:-7.5].active = YES;
            [_widgetView2.leadingAnchor constraintEqualToAnchor:self.centerXAnchor constant:7.5].active = YES;
            [_widgetView2.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset].active = YES;
            [_widgetView1.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
            [_widgetView2.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
            if (hasR2) {
                [_widgetView1.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-5].active = YES;
                [_widgetView2.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-5].active = YES;
            } else {
                [_widgetView1.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
                [_widgetView2.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
            }
        } else {
            UIView *v = (w1 != 99) ? _widgetView1 : _widgetView2;
            [v.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset].active = YES;
            [v.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset].active = YES;
            [v.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
            if (hasR2) [v.bottomAnchor constraintEqualToAnchor:self.centerYAnchor constant:-5].active = YES;
            else [v.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
            if ([v respondsToSelector:@selector(updateForBigWidgetView)]) [(id)v updateForBigWidgetView];
        }
    }

    if (hasR2) {
        if (w3 != 99 && w4 != 99) {
            [_widgetView3.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset].active = YES;
            [_widgetView3.trailingAnchor constraintEqualToAnchor:self.centerXAnchor constant:-7.5].active = YES;
            [_widgetView4.leadingAnchor constraintEqualToAnchor:self.centerXAnchor constant:7.5].active = YES;
            [_widgetView4.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset].active = YES;
            if (hasR1) {
                [_widgetView3.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:5].active = YES;
                [_widgetView4.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:5].active = YES;
            } else {
                [_widgetView3.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
                [_widgetView4.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
            }
            [_widgetView3.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
            [_widgetView4.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
        } else {
            UIView *v = (w3 != 99) ? _widgetView3 : _widgetView4;
            [v.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset].active = YES;
            [v.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset].active = YES;
            if (hasR1) [v.topAnchor constraintEqualToAnchor:self.centerYAnchor constant:5].active = YES;
            else [v.topAnchor constraintEqualToAnchor:self.topAnchor constant:5].active = YES;
            [v.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
            if ([v respondsToSelector:@selector(updateForBigWidgetView)]) [(id)v updateForBigWidgetView];
        }
    }
	[self loadWidgetData];
}
-(BOOL)shouldLoadBatteryData { return _widgetType1 == 0 || _widgetType2 == 0 || _widgetType3 == 0 || _widgetType4 == 0; }
-(BOOL)shouldLoadStorageData { return _widgetType1 == 1 || _widgetType2 == 1 || _widgetType3 == 1 || _widgetType4 == 1; }
-(BOOL)shouldLoadWifiData { return _widgetType1 == 2 || _widgetType2 == 2 || _widgetType3 == 2 || _widgetType4 == 2; }
-(BOOL)shouldLoadCellularData { return _widgetType1 == 3 || _widgetType2 == 3 || _widgetType3 == 3 || _widgetType4 == 3 || _widgetType1 == 5 || _widgetType2 == 5 || _widgetType3 == 5 || _widgetType4 == 5; }
-(BOOL)shouldLoadHotspotData { return _widgetType1 == 5 || _widgetType2 == 5 || _widgetType3 == 5 || _widgetType4 == 5; }
-(BOOL)shouldLoadBluetoothData { return _widgetType1 == 6 || _widgetType2 == 6 || _widgetType3 == 6 || _widgetType4 == 6; }
-(void)loadWidgetData {
	if ([self shouldLoadBatteryData]) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSBundle *storageSettingsBundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/BatteryUsageUI.bundle"];
			[storageSettingsBundle load];
			Class healthClass = objc_getClass("BatteryHealthUIController");
			NSString *maximumCapacityPercent = @"—";
			BatteryHealthUIController *instance = [healthClass new];
			if ([instance respondsToSelector:@selector(updateData)] &&
			    [instance respondsToSelector:@selector(getChargeCapacityRemaining)]) {
				[instance updateData];
				NSString *reported = [instance getChargeCapacityRemaining];
				if ([reported isKindOfClass:[NSString class]]) maximumCapacityPercent = reported;
			}
			BOOL useBatteryHealth = ![maximumCapacityPercent isEqualToString:@"—"];

			dispatch_async(dispatch_get_main_queue(), ^{
				NSDictionary *data = @{@"useBatteryHealth": @(useBatteryHealth), @"maximumCapacityPercent": maximumCapacityPercent};
				if (_widgetType1 == 0) [(id)_widgetView1 updateForData:data];
				if (_widgetType2 == 0) [(id)_widgetView2 updateForData:data];
                if (_widgetType3 == 0) [(id)_widgetView3 updateForData:data];
                if (_widgetType4 == 0) [(id)_widgetView4 updateForData:data];
			});
		});
	}
	if ([self shouldLoadStorageData]) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSBundle *storageSettingsBundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/StorageSettings.bundle"];
			[storageSettingsBundle load];
			STStorageDiskMonitor *monitor = [objc_getClass("STStorageDiskMonitor") new];
			uint64_t totalDiskSpace = monitor.deviceSize;
			uint64_t usedDiskSpace = 0;
			if (monitor && [monitor respondsToSelector:@selector(updateDiskSpace)]) [monitor updateDiskSpace];
			if ([monitor respondsToSelector:@selector(storageSpace)]) {
                id sp = [monitor performSelector:@selector(storageSpace)];
                id used = [sp respondsToSelector:@selector(usedBytes)] ? [sp valueForKey:@"usedBytes"] : nil;
                if ([used isKindOfClass:[NSNumber class]]) usedDiskSpace = [used unsignedLongLongValue];
            }
            if (usedDiskSpace == 0 && [monitor respondsToSelector:@selector(lastFree)]) {
                uint64_t free = monitor.lastFree;
                if (free <= totalDiskSpace) usedDiskSpace = totalDiskSpace - free;
            }
			dispatch_async(dispatch_get_main_queue(), ^{
				NSDictionary *data = @{@"usedDiskSpace": @(usedDiskSpace), @"totalDiskSpace": @(totalDiskSpace)};
				if (_widgetType1 == 1) [(id)_widgetView1 updateForData:data];
				if (_widgetType2 == 1) [(id)_widgetView2 updateForData:data];
                if (_widgetType3 == 1) [(id)_widgetView3 updateForData:data];
                if (_widgetType4 == 1) [(id)_widgetView4 updateForData:data];
			});
		});
	}
	if ([self shouldLoadWifiData]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *result = getIPAddress();
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *data = @{@"ipAddress": result};
                if (_widgetType1 == 2) [(id)_widgetView1 updateForData:data];
                if (_widgetType2 == 2) [(id)_widgetView2 updateForData:data];
                if (_widgetType3 == 2) [(id)_widgetView3 updateForData:data];
                if (_widgetType4 == 2) [(id)_widgetView4 updateForData:data];
            });
        });
	}
	if ([self shouldLoadCellularData]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            Class cacheClass = NSClassFromString(@"PSUICoreTelephonyDataCache");
            if (!cacheClass) {
                [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/SettingsCellular.framework"] load];
                [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/SettingsCellularUI.framework"] load];
                cacheClass = NSClassFromString(@"PSUICoreTelephonyDataCache");
            }
            
            CoreTelephonyClient_Decl *client = nil;
            if ([cacheClass respondsToSelector:@selector(sharedInstance)]) {
                id cache = [cacheClass performSelector:@selector(sharedInstance)];
                if (cache && [cache respondsToSelector:@selector(client)]) {
                    client = [cache valueForKey:@"client"];
                }
            }
            
            if (!client) {
                Class ctClientClass = NSClassFromString(@"CoreTelephonyClient");
                if (!ctClientClass) {
                    [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CoreTelephony.framework"] load];
                    ctClientClass = NSClassFromString(@"CoreTelephonyClient");
                }
                if (ctClientClass) {
                    client = [(CoreTelephonyClient_Decl *)[ctClientClass alloc] initWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
                }
            }
            
            if (client && [client respondsToSelector:@selector(dataUsageForLastPeriods:completion:)]) {
                [client dataUsageForLastPeriods:2 completion:^(id deviceDataUsage, NSError *error) {
                    unsigned long long cellularBytes = 0, hotspotBytes = 0;
                    accumulateUsage(deviceDataUsage, &cellularBytes, &hotspotBytes);

                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSDictionary *cData = @{@"cellularUsage": @(cellularBytes)};
                        NSDictionary *hData = @{@"hotspotUsage": @(hotspotBytes)};
                        if (_widgetType1 == 3) [(id)_widgetView1 updateForData:cData];
                        if (_widgetType2 == 3) [(id)_widgetView2 updateForData:cData];
                        if (_widgetType3 == 3) [(id)_widgetView3 updateForData:cData];
                        if (_widgetType4 == 3) [(id)_widgetView4 updateForData:cData];
                        
                        if (_widgetType1 == 5) [(id)_widgetView1 updateForData:hData];
                        if (_widgetType2 == 5) [(id)_widgetView2 updateForData:hData];
                        if (_widgetType3 == 5) [(id)_widgetView3 updateForData:hData];
                        if (_widgetType4 == 5) [(id)_widgetView4 updateForData:hData];
                    });
                }];
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *zeroData = @{@"cellularUsage": @0};
                NSDictionary *zeroHotspot = @{@"hotspotUsage": @0};
                if (_widgetType1 == 3) [(id)_widgetView1 updateForData:zeroData];
                if (_widgetType2 == 3) [(id)_widgetView2 updateForData:zeroData];
                if (_widgetType3 == 3) [(id)_widgetView3 updateForData:zeroData];
                if (_widgetType4 == 3) [(id)_widgetView4 updateForData:zeroData];
                if (_widgetType1 == 5) [(id)_widgetView1 updateForData:zeroHotspot];
                if (_widgetType2 == 5) [(id)_widgetView2 updateForData:zeroHotspot];
                if (_widgetType3 == 5) [(id)_widgetView3 updateForData:zeroHotspot];
                if (_widgetType4 == 5) [(id)_widgetView4 updateForData:zeroHotspot];
            });
        });
	}
    if ([self shouldLoadHotspotData]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL isHotspotActive = NO;
            struct ifaddrs *interfaces = NULL;
            if(getifaddrs(&interfaces) == 0) {
                struct ifaddrs *interface = interfaces;
                while(interface != NULL) {
                    if(interface->ifa_name && (interface->ifa_flags & IFF_UP) == IFF_UP) {
                        if(strcmp(interface->ifa_name, "bridge100") == 0) {
                            isHotspotActive = YES;
                            break;
                        }
                    }
                    interface = interface->ifa_next;
                }
                freeifaddrs(interfaces);
            }
            if (!isHotspotActive) {
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.MobileInternetSharing.plist"];
                id sharing = dict[@"1022"];
                if ([sharing isKindOfClass:[NSNumber class]] && [sharing intValue] != 0) {
                    isHotspotActive = YES;
                }
            }
            // Only while the bridge is up: with the hotspot off there are no
            // clients to report, which is also why no staleness window is
            // needed on a file written every few seconds while it is up.
            NSMutableDictionary *data =
                [@{@"hotspotActive": @(isHotspotActive)} mutableCopy];
            if (isHotspotActive) {
                NSArray *clients = hotspotProClients();
                if (clients) {
                    data[@"hotspotClientCount"] = @(clients.count);
                    if (clients.count == 1) {
                        NSDictionary *only = clients.firstObject;
                        id name = [only isKindOfClass:[NSDictionary class]] ? only[@"name"] : nil;
                        if ([name isKindOfClass:[NSString class]] && [name length])
                            data[@"hotspotClientName"] = name;
                    }
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (_widgetType1 == 5) [(id)_widgetView1 updateForData:data];
                if (_widgetType2 == 5) [(id)_widgetView2 updateForData:data];
                if (_widgetType3 == 5) [(id)_widgetView3 updateForData:data];
                if (_widgetType4 == 5) [(id)_widgetView4 updateForData:data];
            });
        });
    }
    if ([self shouldLoadBluetoothData]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (!NSClassFromString(@"BluetoothManager")) {
                [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/BluetoothManager.framework"] load];
            }
            // BluetoothManager asserts unless it is created and used on the main thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                Class btClass = NSClassFromString(@"BluetoothManager");
                _btManager = [btClass respondsToSelector:@selector(sharedInstance)] ? [btClass performSelector:@selector(sharedInstance)] : nil;
                if (_btManager && !_btObserving) {
                    _btObserving = YES;
                    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
                    for (NSString *name in @[@"BluetoothAvailabilityChangedNotification",
                                             @"BluetoothConnectabilityChangedNotification",
                                             @"BluetoothDeviceConnectSuccessNotification",
                                             @"BluetoothDeviceDisconnectSuccessNotification",
                                             @"BluetoothPowerChangedNotification"]) {
                        [nc addObserver:self selector:@selector(refreshBluetooth) name:name object:nil];
                    }
                }
                [self refreshBluetooth];
            });
        });
    }
}
-(void)refreshBluetooth {
    id manager = _btManager;
    NSString *devName = nil;
    if (manager) {
        NSArray *devices = [manager respondsToSelector:@selector(connectedDevices)] ?
            [manager performSelector:@selector(connectedDevices)] : nil;
        if (![devices isKindOfClass:[NSArray class]] || devices.count == 0) {
            if ([manager respondsToSelector:@selector(pairedDevices)]) {
                NSArray *paired = [manager performSelector:@selector(pairedDevices)];
                if ([paired isKindOfClass:[NSArray class]]) {
                    NSMutableArray *connected = [NSMutableArray array];
                    for (id d in paired) {
                        @try {
                            if ([[d valueForKey:@"connected"] boolValue]) [connected addObject:d];
                        } @catch (__unused NSException *e) {}
                    }
                    devices = connected;
                }
            }
        }
        if ([devices isKindOfClass:[NSArray class]] && devices.count > 0) {
            id dev = devices.firstObject;
            if ([dev respondsToSelector:@selector(name)]) {
                NSString *n = [dev performSelector:@selector(name)];
                if ([n isKindOfClass:[NSString class]] && n.length > 0) devName = n;
            }
        }
    }
    if (!devName) {
        // Nothing connected. If the manager is still attaching, wait for a
        // notification rather than guessing; otherwise this is a real "not connected".
        BOOL available = YES;
        if ([manager respondsToSelector:@selector(available)]) available = [[manager valueForKey:@"available"] boolValue];
        if (!available) return;
        devName = @"Not Connected";
    }
    NSDictionary *data = @{@"btDevice": devName};
    if (_widgetType1 == 6) [(id)_widgetView1 updateForData:data];
    if (_widgetType2 == 6) [(id)_widgetView2 updateForData:data];
    if (_widgetType3 == 6) [(id)_widgetView3 updateForData:data];
    if (_widgetType4 == 6) [(id)_widgetView4 updateForData:data];
}
-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
-(void)setWidgetBackgrounds {
    CFPreferencesAppSynchronize(CFSTR("com.shepgoba.swprefs"));
    
    UIColor *bgColor = [UIColor whiteColor];
	if (@available(iOS 13, *)) {
		if ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark) {
			bgColor = UIColor.tableCellGroupedBackgroundColor;
		}
	}
    
	if (_widgetView1) _widgetView1.backgroundColor = getBoolPref(@"transparentMode1", NO) ? UIColor.clearColor : bgColor;
	if (_widgetView2) _widgetView2.backgroundColor = getBoolPref(@"transparentMode2", NO) ? UIColor.clearColor : bgColor;
    if (_widgetView3) _widgetView3.backgroundColor = getBoolPref(@"transparentMode3", NO) ? UIColor.clearColor : bgColor;
    if (_widgetView4) _widgetView4.backgroundColor = getBoolPref(@"transparentMode4", NO) ? UIColor.clearColor : bgColor;
}
-(void)applyCustomBackgrounds {
    CFPreferencesAppSynchronize(CFSTR("com.shepgoba.swprefs"));
    
    BOOL c1 = getBoolPref(@"customBgEnabled1", NO);
    NSString *cp1 = getPref(@"customBgPath1");
    BOOL c2 = getBoolPref(@"customBgEnabled2", NO);
    NSString *cp2 = getPref(@"customBgPath2");
    BOOL c3 = getBoolPref(@"customBgEnabled3", NO);
    NSString *cp3 = getPref(@"customBgPath3");
    BOOL c4 = getBoolPref(@"customBgEnabled4", NO);
    NSString *cp4 = getPref(@"customBgPath4");

    if (c1 && cp1.length > 0 && _widgetView1 && [_widgetView1 respondsToSelector:@selector(setCustomBackgroundImageWithPath:)]) {
        [(id)_widgetView1 setCustomBackgroundImageWithPath:cp1];
        _widgetView1.backgroundColor = UIColor.clearColor;
    }
    if (c2 && cp2.length > 0 && _widgetView2 && [_widgetView2 respondsToSelector:@selector(setCustomBackgroundImageWithPath:)]) {
        [(id)_widgetView2 setCustomBackgroundImageWithPath:cp2];
        _widgetView2.backgroundColor = UIColor.clearColor;
    }
    if (c3 && cp3.length > 0 && _widgetView3 && [_widgetView3 respondsToSelector:@selector(setCustomBackgroundImageWithPath:)]) {
        [(id)_widgetView3 setCustomBackgroundImageWithPath:cp3];
        _widgetView3.backgroundColor = UIColor.clearColor;
    }
    if (c4 && cp4.length > 0 && _widgetView4 && [_widgetView4 respondsToSelector:@selector(setCustomBackgroundImageWithPath:)]) {
        [(id)_widgetView4 setCustomBackgroundImageWithPath:cp4];
        _widgetView4.backgroundColor = UIColor.clearColor;
    }
}
@end
