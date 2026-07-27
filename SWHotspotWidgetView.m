#import "SWHotspotWidgetView.h"

@implementation SWHotspotWidgetView
-(instancetype)init {
    if (self = [super init]) {
        self.iconImage = @"hotspoticon";
        self.widgetHeaderLocalizationString = @"Hotspot";
        self.prefsURL = @"prefs:root=INTERNET_TETHERING";
    }
    return self;
}
-(void)additionalSetup {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.statusLabel];

    self.usageLabel = [[UILabel alloc] init];
    self.usageLabel.font = [UIFont boldSystemFontOfSize:13];
    self.usageLabel.textAlignment = NSTextAlignmentCenter;
    self.usageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.usageLabel.adjustsFontSizeToFitWidth = YES;
    self.usageLabel.minimumScaleFactor = 0.8;
    [self addSubview:self.usageLabel];
    
    UILayoutGuide *guide = [[UILayoutGuide alloc] init];
    [self addLayoutGuide:guide];
    [guide.topAnchor constraintEqualToAnchor:self.widgetHeaderLabel.bottomAnchor].active = YES;
    [guide.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;

    [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5].active = YES;
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5].active = YES;
    [self.statusLabel.bottomAnchor constraintEqualToAnchor:guide.centerYAnchor].active = YES;

    [self.usageLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5].active = YES;
    [self.usageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5].active = YES;
    [self.usageLabel.topAnchor constraintEqualToAnchor:guide.centerYAnchor].active = YES;
}
-(void)updateForData:(NSDictionary *)data {
    if (data[@"hotspotActive"]) {
        BOOL isActive = [data[@"hotspotActive"] boolValue];
        self.statusLabel.text = isActive ? @"Status: Enabled" : @"Status: Disabled";
    }
    if (data[@"hotspotUsage"]) {
        unsigned long long bytes = [data[@"hotspotUsage"] unsignedLongLongValue];
        NSString *formattedBytes = [NSByteCountFormatter stringFromByteCount:bytes countStyle:NSByteCountFormatterCountStyleFile];
        self.usageLabel.text = [NSString stringWithFormat:@"Data Usage: %@", formattedBytes];
    }
}
@end
