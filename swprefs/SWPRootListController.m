#import "SWPRootListController.h"
#import "SWBackgroundCache.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <PhotosUI/PhotosUI.h>
#import <roothide.h>
#import <spawn.h>

static const CGFloat kSWPIconSide = 80.0;
static const CGFloat kSWPHeaderGap = 16.0;
// Estimated to fit the 254 pt beside the icon on a 14 Pro Max; layoutSubviews
// shrinks the block if it does not.
static const CGFloat kSWPNameSize = 34.0;
static const CGFloat kSWPVersionSize = 15.0;
static const CGFloat kSWPSchemeSize = 13.0;
static const CGFloat kSWPNameToVersion = 24.0;
static const CGFloat kSWPVersionToScheme = 19.0;

static UIFont *SWPHeaderNameFont(CGFloat size) {
    UIFontDescriptor *bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle]
                                 fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return [UIFont fontWithDescriptor:bold size:size];
}

// theos defines exactly one of these, so nothing needs wiring in the Makefile.
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PACKAGE_SCHEME "roothide"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#define PACKAGE_SCHEME "rootless"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTFUL)
#define PACKAGE_SCHEME "rootful"
#else
#error theos defined no package scheme
#endif

// Where the name's first baseline sits relative to the icon's centre so that the
// three lines together are centred on it.
static CGFloat SWPNameBaselineOffset(CGFloat scale) {
    UIFont *reference = SWPHeaderNameFont(kSWPNameSize * scale);
    UIFont *scheme = [UIFont systemFontOfSize:kSWPSchemeSize * scale];
    CGFloat height = reference.ascender + (kSWPNameToVersion + kSWPVersionToScheme) * scale - scheme.descender;
    return reference.ascender - height / 2.0;
}

@interface SWPHeaderCell : PSTableCell
@end

@implementation SWPHeaderCell {
    UILabel *_name;
    UILabel *_version;
    UILabel *_scheme;
    UIStackView *_text;
    NSLayoutConstraint *_nameBaseline;
    CGFloat _scale;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
    if (!self)
        return nil;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon" inBundle:bundle withConfiguration:nil]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFill;
    icon.clipsToBounds = YES;
    icon.layer.cornerCurve = kCACornerCurveContinuous;
    icon.layer.cornerRadius = kSWPIconSide * 0.225;
    [self.contentView addSubview:icon];

    _name = [[UILabel alloc] init];
    _name.text = @"SettingsWidgets";
    // The middle of the icon's purple gradient.
    _name.textColor = [UIColor colorWithRed:0x98 / 255.0 green:0x6d / 255.0 blue:0xfa / 255.0 alpha:1.0];

    _version = [[UILabel alloc] init];
    _version.text = @"Version " PACKAGE_VERSION;
    _version.textColor = [UIColor systemGrayColor];

    _scheme = [[UILabel alloc] init];
    _scheme.text = @PACKAGE_SCHEME.capitalizedString;
    _scheme.textColor = [UIColor systemGrayColor];

    // Spacing is baseline to baseline, so the large name does not push the two
    // lines under it away with its own leading.
    _text = [[UIStackView alloc] initWithArrangedSubviews:@[ _name, _version, _scheme ]];
    _text.axis = UILayoutConstraintAxisVertical;
    _text.alignment = UIStackViewAlignmentLeading;
    _text.baselineRelativeArrangement = YES;
    _text.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_text];
    _nameBaseline = [_name.firstBaselineAnchor constraintEqualToAnchor:icon.centerYAnchor];
    [self applyTextScale:1.0];

    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:kSWPIconSide],
        [icon.heightAnchor constraintEqualToConstant:kSWPIconSide],
        [icon.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kSWPHeaderGap],
        _nameBaseline
    ]];

    return self;
}

// Fonts and spacing scale together so the three lines keep their proportions.
// The icon is never scaled.
- (void)applyTextScale:(CGFloat)scale {
    if (scale == _scale)
        return;
    _scale = scale;
    _name.font = SWPHeaderNameFont(kSWPNameSize * scale);
    _version.font = [UIFont systemFontOfSize:kSWPVersionSize * scale];
    _scheme.font = [UIFont systemFontOfSize:kSWPSchemeSize * scale];
    [_text setCustomSpacing:kSWPNameToVersion * scale afterView:_name];
    [_text setCustomSpacing:kSWPVersionToScheme * scale afterView:_version];
    _nameBaseline.constant = SWPNameBaselineOffset(scale);
}

// Full size wherever the name fits beside the icon; a narrower phone shrinks the
// whole block by the name's overflow rather than truncating it.
- (void)layoutSubviews {
    CGFloat available = CGRectGetWidth(self.contentView.layoutMarginsGuide.layoutFrame) - kSWPIconSide - kSWPHeaderGap;
    CGFloat natural = [_name.text sizeWithAttributes:@{ NSFontAttributeName: SWPHeaderNameFont(kSWPNameSize) }].width;
    [self applyTextScale:(available > 0 && natural > available) ? available / natural : 1.0];
    [super layoutSubviews];
}

// The row carries the page's own heading, not a setting, so it takes no
// selection, no separator and none of the grouped background.
- (void)setSeparatorStyle:(UITableViewCellSeparatorStyle)style {
    [super setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

- (void)setBackgroundColor:(UIColor *)color {
    [super setBackgroundColor:[UIColor clearColor]];
}

- (UITableViewCellSelectionStyle)selectionStyle {
    return UITableViewCellSelectionStyleNone;
}

@end

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

        PSSpecifier *header = [PSSpecifier preferenceSpecifierNamed:@""
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:nil
                                                               cell:PSStaticTextCell
                                                               edit:nil];
        [header setProperty:[SWPHeaderCell class] forKey:@"cellClass"];
        [header setProperty:@142 forKey:@"height"];
        [specifiers insertObject:header atIndex:0];

        // Without a group of its own the header renders as the first row of
        // whatever section follows, sharing its background and separators.
        PSSpecifier *first = [PSSpecifier preferenceSpecifierNamed:@"Settings" target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
        [specifiers insertObject:first atIndex:1];

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
- (void)showAlertTitled:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Switching a custom background off leaves its image and decoded frames on disk,
// which is what you want if it is going back on. This is the way back out, and it
// only ever touches slots whose switch is already off.
- (void)clearUnusedBackgrounds {
    NSString *dir = jbroot(@"/var/mobile/Library/Preferences/SettingsWidgets");
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (int n = 1; n <= 4; n++) {
        id on = CFBridgingRelease(CFPreferencesCopyAppValue(
            (__bridge CFStringRef)[NSString stringWithFormat:@"customBgEnabled%d", n],
            CFSTR("com.shepgoba.swprefs")));
        if ([on isKindOfClass:[NSNumber class]] && [on boolValue]) continue;

        NSString *prefix = [NSString stringWithFormat:@"bg%d.", n];
        for (NSString *file in [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[]) {
            if ([file hasPrefix:prefix]) [paths addObject:[dir stringByAppendingPathComponent:file]];
        }
        [paths addObject:[[dir stringByAppendingPathComponent:@".bgcache"]
                          stringByAppendingPathComponent:[NSString stringWithFormat:@"bg%d", n]]];
    }

    unsigned long long freed = 0;
    NSUInteger removed = 0;
    for (NSString *path in paths) {
        if (![fm fileExistsAtPath:path]) continue;
        NSDirectoryEnumerator *walk = [fm enumeratorAtPath:path];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if (attrs && ![attrs[NSFileType] isEqual:NSFileTypeDirectory]) {
            freed += [attrs fileSize];
        } else {
            for (NSString *sub in walk) {
                NSDictionary *subAttrs = [fm attributesOfItemAtPath:[path stringByAppendingPathComponent:sub] error:nil];
                if (subAttrs) freed += [subAttrs fileSize];
            }
        }
        if ([fm removeItemAtPath:path error:nil]) removed++;
    }

    if (removed == 0) {
        [self showAlertTitled:@"Nothing to Clear" message:@"Every custom background that is switched off has already been cleared."];
        return;
    }
    [self showAlertTitled:@"Cleared"
                  message:[NSString stringWithFormat:@"Freed %@.",
                           [NSByteCountFormatter stringFromByteCount:freed countStyle:NSByteCountFormatterCountStyleFile]]];
}

- (void)openTwitter { [self openURL:@"https://twitter.com/shepgoba"]; }
- (void)openSourceCode { [self openURL:@"https://github.com/shepgoba/SettingsWidgets"]; }
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
                
                NSError *copyError = nil;
                if (![fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&copyError]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showAlertTitled:@"Could Not Save"
                                      message:copyError.localizedDescription ?: @"The image could not be copied."];
                    });
                    return;
                }

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
                    [self showAlertTitled:@"Success" message:@"Background image saved successfully!"];
                });
            }
        }];
    }
}
@end
