#import "SWWidgetView.h"
#import "SWBackgroundCache.h"
#import <objc/runtime.h>
#import <roothide.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

@interface PSURLManager : NSObject
+ (id)sharedManager;
- (void)processURL:(id)arg1 animated:(_Bool)arg2 fromSearch:(_Bool)arg3 withCompletion:(id)arg4;
@end

@interface SWWidgetView ()
@property (nonatomic, strong) UIImageView *customBackgroundImageView;
@property (nonatomic, assign) BOOL backgroundAnimationAllowed;
@end

@implementation SWWidgetView
-(instancetype)init {
    if (self = [super init]) {
        self.hasPrefsURL = YES;
        self.backgroundAnimationAllowed = YES;
    }
    return self;
}
-(void)setup {
	NSBundle *tweakBundle = [[NSBundle alloc] initWithPath:jbroot(@"/Library/Application Support/SettingsWidgets")];
    UIImage *iconImage = [UIImage imageNamed:self.iconImage inBundle:tweakBundle compatibleWithTraitCollection:nil];
    if (!iconImage) {
        NSString *imagePath = [tweakBundle pathForResource:self.iconImage ofType:@"png"];
        if (imagePath) iconImage = [UIImage imageWithContentsOfFile:imagePath];
    }

    CGFloat iconW = iconImage ? iconImage.size.width : 29;
    CGFloat iconH = iconImage ? iconImage.size.height : 29;

    _widgetIconImageView = [[UIImageView alloc] init];
    _widgetIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _widgetIconImageView.layer.masksToBounds = NO;
    _widgetIconImageView.layer.opaque = NO;

    if (iconImage) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
            format.opaque = NO;
            format.scale = iconImage.scale;
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(iconW, iconH) format:format];

            UIImage *roundedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
                CGFloat radius = 6.5 * (iconW / 29.0);
                UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, iconW, iconH) cornerRadius:radius];
                [path addClip];
                [iconImage drawInRect:CGRectMake(0, 0, iconW, iconH)];
            }];

            // The block holds roundedImage, so the CGImage stays alive until the main queue uses it.
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf.widgetIconImageView.layer.contents = (__bridge id)roundedImage.CGImage;
                    strongSelf.widgetIconImageView.layer.contentsGravity = kCAGravityResizeAspect;
                }
            });
        });
    }

    _widgetHeaderLabel = [[UILabel alloc] init];
	_widgetHeaderLabel.text = [tweakBundle localizedStringForKey:self.widgetHeaderLocalizationString value:self.widgetHeaderLocalizationString table:nil];
	_widgetHeaderLabel.font = [UIFont boldSystemFontOfSize:15];
    _widgetHeaderLabel.textAlignment = NSTextAlignmentLeft;
    _widgetHeaderLabel.adjustsFontSizeToFitWidth = YES;
	_widgetHeaderLabel.minimumScaleFactor = 0.6;
	_widgetHeaderLabel.numberOfLines = 2;
    _widgetHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;

	[self addSubview: _widgetIconImageView];
	[self addSubview: _widgetHeaderLabel];

	[_widgetHeaderLabel.trailingAnchor constraintEqualToAnchor: self.trailingAnchor constant:-7.5].active = YES;
	[_widgetHeaderLabel.leadingAnchor constraintEqualToAnchor: _widgetIconImageView.trailingAnchor constant:7.5].active = YES;
	[_widgetHeaderLabel.centerYAnchor constraintEqualToAnchor: _widgetIconImageView.centerYAnchor].active = YES;

	[_widgetIconImageView.topAnchor constraintEqualToAnchor: self.topAnchor constant: 12.5].active = YES;
	[_widgetIconImageView.leadingAnchor constraintEqualToAnchor: self.leadingAnchor constant: 12.5].active = YES;
	[_widgetIconImageView.widthAnchor constraintEqualToConstant: iconW].active = YES;
	[_widgetIconImageView.heightAnchor constraintEqualToConstant: iconH].active = YES;

	[self additionalSetup];
}

-(void)setCustomBackgroundImageWithPath:(NSString *)path {
    if (!path || path.length == 0) return;
    NSString *safePath = [path lastPathComponent];
    NSString *baseDir = jbroot(@"/var/mobile/Library/Preferences/SettingsWidgets");
    NSString *fullPath = [baseDir stringByAppendingPathComponent:safePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) return;

    if (!self.customBackgroundImageView) {
        self.customBackgroundImageView = [[UIImageView alloc] init];
        self.customBackgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.customBackgroundImageView.clipsToBounds = YES;
        self.customBackgroundImageView.layer.cornerRadius = self.layer.cornerRadius;
        self.customBackgroundImageView.layer.cornerCurve = kCACornerCurveContinuous;
        self.customBackgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self insertSubview:self.customBackgroundImageView atIndex:0];
        [self.customBackgroundImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        [self.customBackgroundImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        [self.customBackgroundImageView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
        [self.customBackgroundImageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
    }
    NSString *sourceName = safePath;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Show the first frame near-instantly; build the cache once if missing or stale.
        UIImage *firstFrame = SWLoadBackgroundFirstFrame(sourceName);
        if (!firstFrame) {
            SWRebuildBackgroundCache(sourceName);
            firstFrame = SWLoadBackgroundFirstFrame(sourceName);
        }
        if (!firstFrame) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.customBackgroundImageView.image = firstFrame;
        });

        // Load the full animation and switch to it once ready.
        NSDictionary *cache = SWLoadBackgroundCache(sourceName);
        NSArray *frames = cache[@"frames"];
        if (frames.count <= 1) return;
        NSTimeInterval duration = [cache[@"duration"] doubleValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.customBackgroundImageView.animationImages = frames;
            strongSelf.customBackgroundImageView.animationDuration = duration > 0 ? duration : frames.count * 0.1;
            // The decode can finish after the page has been navigated away from.
            if (strongSelf.backgroundAnimationAllowed) [strongSelf.customBackgroundImageView startAnimating];
        });
    });
}

static void applyColorToSubviews(UIView *view, UIColor *color, UILabel *excludeLabel) {
    NSArray *subviews = view.subviews;
    NSUInteger count = subviews.count;
    for (NSUInteger i = 0; i < count; i++) {
        UIView *v = subviews[i];
        if ([v isKindOfClass:[UILabel class]] && v != excludeLabel) ((UILabel *)v).textColor = color;
        applyColorToSubviews(v, color, excludeLabel);
    }
}

-(void)applyFontColorStyle:(NSInteger)style {
    UIColor *solidColor;
    if (style == 0) {
        solidColor = [UIColor whiteColor];
    } else if (style == 1) {
        solidColor = [UIColor blackColor];
    } else {
        if (@available(iOS 13.0, *)) solidColor = [UIColor labelColor];
        else solidColor = [UIColor blackColor];
    }
    
    self.widgetHeaderLabel.textColor = solidColor;
    applyColorToSubviews(self, solidColor, self.widgetHeaderLabel);
}

-(void)openPrefsURL {
	if (self.hasPrefsURL) {
		static Class managerClass = nil;
		if (!managerClass) managerClass = objc_getClass("PSURLManager");
		if (![managerClass respondsToSelector:@selector(sharedManager)]) return;
		id manager = [managerClass sharedManager];
		if (![manager respondsToSelector:@selector(processURL:animated:fromSearch:withCompletion:)]) return;
		[manager processURL:[NSURL URLWithString:self.prefsURL] animated: YES fromSearch:NO withCompletion:nil];
	}
}
-(void)setBackgroundAnimating:(BOOL)animating {
    self.backgroundAnimationAllowed = animating;
    if (self.customBackgroundImageView.animationImages.count < 2) return;
    if (animating) {
        if (!self.customBackgroundImageView.isAnimating) [self.customBackgroundImageView startAnimating];
    } else {
        [self.customBackgroundImageView stopAnimating];
    }
}
-(void)additionalSetup {}
-(void)updateForBigWidgetView {}
-(void)updateForData:(NSDictionary *)data {}
@end
