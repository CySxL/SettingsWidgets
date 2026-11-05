#import "SWBluetoothWidgetView.h"

@implementation SWBluetoothWidgetView
-(instancetype)init {
    if (self = [super init]) {
        self.iconImage = @"bluetoothicon";
        self.widgetHeaderLocalizationString = @"Bluetooth";
        self.prefsURL = @"prefs:root=Bluetooth";
    }
    return self;
}
-(void)additionalSetup {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.statusLabel];

    self.deviceLabel = [[UILabel alloc] init];
    self.deviceLabel.font = [UIFont boldSystemFontOfSize:13];
    self.deviceLabel.textAlignment = NSTextAlignmentCenter;
    self.deviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceLabel.adjustsFontSizeToFitWidth = YES;
    self.deviceLabel.minimumScaleFactor = 0.8;
    self.deviceLabel.numberOfLines = 2;
    [self addSubview:self.deviceLabel];

    [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5].active = YES;
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5].active = YES;

    [self.deviceLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:5].active = YES;
    [self.deviceLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5].active = YES;
    [self.deviceLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15].active = YES;
    [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.deviceLabel.topAnchor].active = YES;
}
-(void)updateForData:(NSDictionary *)data {
    NSString *device = data[@"btDevice"];
    if (![device isKindOfClass:[NSString class]] || device.length == 0) {
        self.statusLabel.text = @"Disconnected";
        self.deviceLabel.text = @"";
    } else {
        self.statusLabel.text = @"Connected";
        self.deviceLabel.text = device;
    }
}
@end
