#import "SWPRootListController.h"
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
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
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
