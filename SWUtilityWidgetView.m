#import "SWUtilityWidgetView.h"
#include <spawn.h>
#import <roothide.h>

@implementation SWUtilityWidgetView
-(instancetype)init {
    if (self = [super init]) {
        self.iconImage = @"utilityicon";
        self.widgetHeaderLocalizationString = @"UTILITY_WIDGET_HEADER";
        self.prefsURL = @"";
        self.hasPrefsURL = YES;
    }
    return self;
}
-(void)additionalSetup {
    UIButton *safeModeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [[UIImage systemImageNamed:@"shield.lefthalf.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [safeModeBtn setImage:img forState:UIControlStateNormal];
    } else {
        [safeModeBtn setTitle:@"Safe" forState:UIControlStateNormal];
    }
    safeModeBtn.tintColor = [UIColor systemOrangeColor];
    [safeModeBtn addTarget:self action:@selector(safeMode) forControlEvents:UIControlEventTouchUpInside];
    safeModeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:safeModeBtn];

    UIButton *respringBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [respringBtn setImage:img forState:UIControlStateNormal];
    } else {
        [respringBtn setTitle:@"Respring" forState:UIControlStateNormal];
    }
    respringBtn.tintColor = [UIColor systemRedColor];
    [respringBtn addTarget:self action:@selector(respring) forControlEvents:UIControlEventTouchUpInside];
    respringBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:respringBtn];

    [respringBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-15].active = YES;
    [respringBtn.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    [respringBtn.widthAnchor constraintEqualToConstant:30].active = YES;
    [respringBtn.heightAnchor constraintEqualToConstant:30].active = YES;

    [safeModeBtn.trailingAnchor constraintEqualToAnchor:respringBtn.leadingAnchor constant:-15].active = YES;
    [safeModeBtn.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    [safeModeBtn.widthAnchor constraintEqualToConstant:30].active = YES;
    [safeModeBtn.heightAnchor constraintEqualToConstant:30].active = YES;
    
    [self bringSubviewToFront:respringBtn];
    [self bringSubviewToFront:safeModeBtn];
}

-(void)openPrefsURL {
    NSBundle *bundle = [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/swprefs.bundle")];
    if (![bundle isLoaded]) [bundle load];
    Class cls = [bundle principalClass] ?: NSClassFromString(@"SWPRootListController");
    if (!cls) return;
    UIViewController *pane = [[cls alloc] init];
    pane.title = @"SettingsWidgets";
    [[self parentViewController].navigationController pushViewController:pane animated:YES];
}

-(UIViewController *)parentViewController {
    UIResponder *responder = self;
    while ([responder isKindOfClass:[UIView class]]) {
        responder = [responder nextResponder];
    }
    if ([responder isKindOfClass:[UIViewController class]]) {
        return (UIViewController *)responder;
    }
    return nil;
}

-(void)respring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring" message:@"Are you sure you want to Respring?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, jbroot("/usr/bin/killall"), NULL, NULL, (char *const *)argv, NULL);
    }]];
    [[self parentViewController] presentViewController:alert animated:YES completion:nil];
}

-(void)safeMode {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Safe Mode" message:@"Are you sure you want to enter Safe Mode?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        pid_t pid;
        const char *argv[] = {"killall", "-SEGV", "SpringBoard", NULL};
        posix_spawn(&pid, jbroot("/usr/bin/killall"), NULL, NULL, (char *const *)argv, NULL);
    }]];
    [[self parentViewController] presentViewController:alert animated:YES completion:nil];
}

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            CGPoint buttonPoint = [subview convertPoint:point fromView:self];
            if ([subview pointInside:buttonPoint withEvent:event]) {
                return subview;
            }
        }
    }
    return [super hitTest:point withEvent:event];
}
@end
