#import <UIKit/UIKit.h>
#import "SWWidgetView.h"

@interface SWWidgetContainerView : UIView
@property (nonatomic, strong) SWWidgetView *widgetView1;
@property (nonatomic, strong) SWWidgetView *widgetView2;
@property (nonatomic, assign) SWWidgetType widgetType1;
@property (nonatomic, assign) SWWidgetType widgetType2;

-(void)setupWidgetsWithType1:(int)w1 type2:(int)w2 type3:(int)w3 type4:(int)w4 widgetInset:(int)inset cornerRadius:(int)cr fontColor1:(int)fc1 fontColor2:(int)fc2 fontColor3:(int)fc3 fontColor4:(int)fc4;
-(void)setWidgetBackgrounds;
-(void)applyCustomBackgrounds;
-(void)setWidgetsAnimating:(BOOL)animating;
@end
