#import <UIKit/UIKit.h>

typedef int SWWidgetType;

@interface SWWidgetView : UIView
@property (nonatomic, strong) UIImageView *widgetIconImageView;
@property (nonatomic, strong) UILabel *widgetHeaderLabel;
@property (nonatomic, strong) NSString *widgetHeaderLocalizationString;
@property (nonatomic, strong) NSString *iconImage;
@property (nonatomic, strong) NSString *prefsURL;
@property (nonatomic, assign) BOOL hasPrefsURL;
-(void)setup;
-(void)additionalSetup;
-(void)updateForBigWidgetView;
-(void)updateForData:(NSDictionary *)data;
-(void)applyFontColorStyle:(NSInteger)style;
-(void)setBackgroundAnimating:(BOOL)animating;
@end
