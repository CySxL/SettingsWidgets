#import "SWStorageWidgetView.h"

@implementation SWStorageWidgetView
-(instancetype)init {
    if (self = [super init]) {
        self.iconImage = @"storageicon";
        self.widgetHeaderLocalizationString = @"Storage";
        self.prefsURL = @"prefs:root=General&path=STORAGE_MGMT";
    }
    return self;
}
-(void)additionalSetup {
    self.usageLabel = [[UILabel alloc] init];
    self.usageLabel.font = [UIFont boldSystemFontOfSize:13];
    self.usageLabel.textAlignment = NSTextAlignmentCenter;
    self.usageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.usageLabel.adjustsFontSizeToFitWidth = YES;
    self.usageLabel.minimumScaleFactor = 0.8;
    [self addSubview:self.usageLabel];

    self.bgBar = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        self.bgBar.backgroundColor = [UIColor tertiarySystemFillColor];
    } else {
        self.bgBar.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.3];
    }
    self.bgBar.layer.cornerRadius = 4;
    self.bgBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.bgBar];

    self.fillBar = [[UIView alloc] init];
    self.fillBar.backgroundColor = [UIColor colorWithRed:173.0/255.0 green:171.0/255.0 blue:179.0/255.0 alpha:1.0];
    self.fillBar.layer.cornerRadius = 4;
    self.fillBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bgBar addSubview:self.fillBar];

    UILayoutGuide *guide = [[UILayoutGuide alloc] init];
    [self addLayoutGuide:guide];
    [guide.topAnchor constraintEqualToAnchor:self.widgetHeaderLabel.bottomAnchor].active = YES;
    [guide.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;

    [self.usageLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5].active = YES;
    [self.usageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5].active = YES;
    [self.usageLabel.bottomAnchor constraintEqualToAnchor:guide.centerYAnchor constant:-2].active = YES;

    [self.bgBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:15].active = YES;
    [self.bgBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-15].active = YES;
    [self.bgBar.topAnchor constraintEqualToAnchor:guide.centerYAnchor constant:4].active = YES;
    [self.bgBar.heightAnchor constraintEqualToConstant:8].active = YES;

    [self.fillBar.leadingAnchor constraintEqualToAnchor:self.bgBar.leadingAnchor].active = YES;
    [self.fillBar.topAnchor constraintEqualToAnchor:self.bgBar.topAnchor].active = YES;
    [self.fillBar.bottomAnchor constraintEqualToAnchor:self.bgBar.bottomAnchor].active = YES;
    self.fillWidthConstraint = [self.fillBar.widthAnchor constraintEqualToAnchor:self.bgBar.widthAnchor multiplier:0];
    self.fillWidthConstraint.active = YES;
}
-(void)updateForData:(NSDictionary *)data {
    unsigned long long used = [data[@"usedDiskSpace"] unsignedLongLongValue];
    unsigned long long total = [data[@"totalDiskSpace"] unsignedLongLongValue];
    
    NSString *usedStr = [NSByteCountFormatter stringFromByteCount:used countStyle:NSByteCountFormatterCountStyleFile];
    NSString *totalStr = [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile];
    self.usageLabel.text = [NSString stringWithFormat:@"%@ / %@", usedStr, totalStr];
    
    CGFloat ratio = 0;
    if (total > 0) ratio = (CGFloat)used / (CGFloat)total;
    if (ratio > 1.0) ratio = 1.0;
    
    self.fillWidthConstraint.active = NO;
    self.fillWidthConstraint = [self.fillBar.widthAnchor constraintEqualToAnchor:self.bgBar.widthAnchor multiplier:ratio];
    self.fillWidthConstraint.active = YES;
    
    [UIView animateWithDuration:0.5 animations:^{
        [self layoutIfNeeded];
    }];
}
@end
