#import "SWBatteryWidgetView.h"
#import "utils.h"
#import <objc/runtime.h>

@implementation SWBatteryWidgetView
-(NSString *)iconImage {
	return @"batteryicon";
}
-(NSString *)widgetHeaderLocalizationString {
	return @"BATTERY_WIDGET_HEADER";
}
-(NSString *)prefsURL {
	return @"prefs:root=BATTERY_USAGE";
}

-(void)additionalSetup {
	UIDevice.currentDevice.batteryMonitoringEnabled = YES;
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateBatteryLevelText) name:@"UIDeviceBatteryLevelDidChangeNotification" object:nil];
	_useBatteryHealth = YES;
    _healthLabel = [[UILabel alloc] init];
	_healthLabel.text = _useBatteryHealth ? [NSString stringWithFormat:@"%@: 00%%", localizedStringForKey(@"BATTERY_MAX_CAPACITY")] : [NSString stringWithFormat:@"%@: %.0f%%", localizedStringForKey(@"BATTERY_LEVEL"), [UIDevice currentDevice].batteryLevel*100];
	_healthLabel.font = [UIFont boldSystemFontOfSize:13];
    _healthLabel.textAlignment = NSTextAlignmentCenter;
	_healthLabel.adjustsFontSizeToFitWidth = YES;
	_healthLabel.minimumScaleFactor = 0.6;
	_healthLabel.numberOfLines = 1;
	_healthLabel.translatesAutoresizingMaskIntoConstraints = NO;

	[self addSubview: _healthLabel];

	[_healthLabel.bottomAnchor constraintEqualToAnchor: self.bottomAnchor constant: -15].active = YES;
	[_healthLabel.leadingAnchor constraintEqualToAnchor: self.leadingAnchor constant: 10].active = YES;
	[_healthLabel.trailingAnchor constraintEqualToAnchor: self.trailingAnchor constant: -10].active = YES;
}
-(void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
	UIDevice.currentDevice.batteryMonitoringEnabled = NO;
}
-(void)updateBatteryLevelText {
	if (!_useBatteryHealth) {
		_healthLabel.text = [NSString stringWithFormat:@"%@: %.0f%%", localizedStringForKey(@"BATTERY_LEVEL"), [UIDevice currentDevice].batteryLevel * 100];
	}
}
-(void)updateForData:(NSDictionary *)receievedData {
	NSString *maximumCapacityPercent = receievedData[@"maximumCapacityPercent"];
	BOOL useBatteryHealth = [receievedData[@"useBatteryHealth"] boolValue];
	_useBatteryHealth = useBatteryHealth;
	_healthLabel.text = useBatteryHealth ? [NSString stringWithFormat:@"%@: %@", localizedStringForKey(@"BATTERY_MAX_CAPACITY"), maximumCapacityPercent] : [NSString stringWithFormat:@"%@: %.0f%%", localizedStringForKey(@"BATTERY_LEVEL"), [UIDevice currentDevice].batteryLevel*100];
}

@end
