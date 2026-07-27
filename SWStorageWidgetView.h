#import "SWWidgetView.h"
@interface SWStorageWidgetView : SWWidgetView
@property (nonatomic, strong) UILabel *usageLabel;
@property (nonatomic, strong) UIView *bgBar;
@property (nonatomic, strong) UIView *fillBar;
@property (nonatomic, strong) NSLayoutConstraint *fillWidthConstraint;
@end
