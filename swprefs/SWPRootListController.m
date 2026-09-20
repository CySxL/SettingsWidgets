#import "SWPRootListController.h"
#import "SWBackgroundCache.h"
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import <roothide.h>
#import <spawn.h>

@interface SWPRootListController () <PHPickerViewControllerDelegate>
@property (nonatomic, assign) NSInteger currentPickingIndex;
@end

@implementation SWPRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *applyBtn = [[UIBarButtonItem alloc] initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(apply)];
    self.navigationItem.rightBarButtonItem = applyBtn;
}

- (void)apply {
    [self.view endEditing:YES];
    CFPreferencesAppSynchronize(CFSTR("com.shepgoba.swprefs"));
    pid_t pid;
    const char *argv[] = {"killall", "-9", "Preferences", NULL};
    posix_spawn(&pid, jbroot("/usr/bin/killall"), NULL, NULL, (char *const *)argv, NULL);
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];

        [self removeRowsForDisabledWidgets:specifiers];
        _specifiers = specifiers;
    }
    return _specifiers;
}

// Widgets 2-4 have an enable switch. With it off the widget is not built at all,
// so its type, backgrounds and font colour are five rows that read as settings
// and change nothing. The switch itself and its group header stay.
- (void)removeRowsForDisabledWidgets:(NSMutableArray *)specifiers {
    NSMutableSet *hiddenKeys = [NSMutableSet set];
    NSMutableSet *hiddenIDs = [NSMutableSet set];
    for (int n = 2; n <= 4; n++) {
        id enabled = CFBridgingRelease(CFPreferencesCopyAppValue(
            (__bridge CFStringRef)[NSString stringWithFormat:@"widget%dEnabled", n],
            CFSTR("com.shepgoba.swprefs")));
        BOOL on = [enabled isKindOfClass:[NSNumber class]] ? [enabled boolValue] : (n == 2);
        if (on) continue;
        for (NSString *key in @[@"widgetType%d", @"transparentMode%d", @"customBgEnabled%d", @"fontColor%d"])
            [hiddenKeys addObject:[NSString stringWithFormat:key, n]];
        [hiddenIDs addObject:[NSString stringWithFormat:@"chooseBgBtn%d", n]];
    }
    if (hiddenKeys.count == 0) return;

    NSMutableIndexSet *drop = [NSMutableIndexSet indexSet];
    [specifiers enumerateObjectsUsingBlock:^(PSSpecifier *spec, NSUInteger idx, BOOL *stop) {
        NSString *key = [spec propertyForKey:@"key"];
        NSString *identifier = [spec propertyForKey:@"id"];
        if ([key isKindOfClass:[NSString class]] && [hiddenKeys containsObject:key]) [drop addIndex:idx];
        else if ([identifier isKindOfClass:[NSString class]] && [hiddenIDs containsObject:identifier]) [drop addIndex:idx];
    }];
    [specifiers removeObjectsAtIndexes:drop];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"widget"] && [key hasSuffix:@"Enabled"]) {
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

- (void)openURL:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] openURL:url];
#pragma clang diagnostic pop
    }
}
- (void)openTwitter { [self openURL:@"https://twitter.com/shepgoba"]; }
- (void)openIconTwitter { [self openURL:@"https://twitter.com/JannikCrack"]; }
- (void)openGitHub { [self openURL:@"https://github.com/CySxL"]; }

- (void)presentPickerForIndex:(NSInteger)index {
    self.currentPickingIndex = index;
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)chooseImage1 { [self presentPickerForIndex:1]; }
- (void)chooseImage2 { [self presentPickerForIndex:2]; }
- (void)chooseImage3 { [self presentPickerForIndex:3]; }
- (void)chooseImage4 { [self presentPickerForIndex:4]; }

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    
    NSItemProvider *provider = results.firstObject.itemProvider;
    NSInteger index = self.currentPickingIndex;
    
    if ([provider hasItemConformingToTypeIdentifier:@"public.image"]) {
        [provider loadFileRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSURL *url, NSError *error) {
            if (url) {
                NSString *ext = url.pathExtension.lowercaseString;
                if (ext.length == 0) ext = @"jpg";
                
                NSString *dir = jbroot(@"/var/mobile/Library/Preferences/SettingsWidgets");
                NSFileManager *fm = [NSFileManager defaultManager];
                if (![fm fileExistsAtPath:dir]) {
                    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                }
                
                NSArray *existingFiles = [fm contentsOfDirectoryAtPath:dir error:nil];
                NSString *prefix = [NSString stringWithFormat:@"bg%ld.", (long)index];
                for (NSString *file in existingFiles) {
                    if ([file hasPrefix:prefix]) {
                        [fm removeItemAtPath:[dir stringByAppendingPathComponent:file] error:nil];
                    }
                }
                
                NSString *fileName = [NSString stringWithFormat:@"bg%ld.%@", (long)index, ext];
                NSString *destPath = [dir stringByAppendingPathComponent:fileName];
                
                [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:nil];
                
                NSString *key = [NSString stringWithFormat:@"customBgPath%ld", (long)index];
                CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)fileName, CFSTR("com.shepgoba.swprefs"));
                CFPreferencesAppSynchronize(CFSTR("com.shepgoba.swprefs"));

                // Pre-decode the picked image now so opening Settings later is fast.
                // Request background time so this finishes even if Settings is closed.
                UIApplication *app = [UIApplication sharedApplication];
                __block UIBackgroundTaskIdentifier bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
                    if (bgTask != UIBackgroundTaskInvalid) { [app endBackgroundTask:bgTask]; bgTask = UIBackgroundTaskInvalid; }
                }];
                SWRebuildBackgroundCache(fileName);
                if (bgTask != UIBackgroundTaskInvalid) { [app endBackgroundTask:bgTask]; bgTask = UIBackgroundTaskInvalid; }

                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" message:@"Background image saved successfully!" preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                });
            }
        }];
    }
}
@end
