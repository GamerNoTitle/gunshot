#import "GSAppearance.h"
#import <objc/message.h>

static UIButtonConfiguration *GSGlassConfiguration(void){
 // Resolve the public factory at runtime so an older SDK/iOS can still load us.
 if(@available(iOS 26.0,*)){
  SEL factory=NSSelectorFromString(@"glassButtonConfiguration");
  if([UIButtonConfiguration respondsToSelector:factory]){
   id configuration=((id(*)(id,SEL))objc_msgSend)(UIButtonConfiguration.class,factory);
   if([configuration isKindOfClass:UIButtonConfiguration.class])return configuration;
  }
 }
 return nil;
}
BOOL GSApplyGlassButton(UIButton *button){
 UIButtonConfiguration *configuration=GSGlassConfiguration();
 if(!configuration)return NO;
 configuration.title=[button titleForState:UIControlStateNormal];
 configuration.baseForegroundColor=UIColor.labelColor;
 button.configuration=configuration;
 button.titleLabel.adjustsFontForContentSizeCategory=YES;
 return YES;
}

// A custom view needs to forward the bar item's title, enabled state and action.
// Keep the item as the sender, including after its target/action are changed.
@interface GSGlassBarButtonItem : UIBarButtonItem
- (void)activate:(UIButton *)sender;
@end
@implementation GSGlassBarButtonItem
- (void)setTitle:(NSString *)title{
 [super setTitle:title];
 UIButton *button=(UIButton *)self.customView;
 [button setTitle:title forState:UIControlStateNormal];
 [button invalidateIntrinsicContentSize];
}
- (void)setEnabled:(BOOL)enabled{
 [super setEnabled:enabled];[(UIButton *)self.customView setEnabled:enabled];
}
- (void)activate:(UIButton *)sender{
 if(self.enabled&&self.action)[UIApplication.sharedApplication sendAction:self.action to:self.target from:self forEvent:nil];
}
@end
UIBarButtonItem *GSNavigationButton(NSString *title,id target,SEL action){
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
 [button setTitle:title forState:UIControlStateNormal];
 if(!GSApplyGlassButton(button))return [[UIBarButtonItem alloc]initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action];
 GSGlassBarButtonItem *item=[[GSGlassBarButtonItem alloc]initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action];
 item.customView=button;
 [button addTarget:item action:@selector(activate:) forControlEvents:UIControlEventTouchUpInside];
 // Let intrinsic sizing adapt to localized titles. Avoid forcing a fixed width.
 [button sizeToFit];
 // New-SDK hosts may otherwise put a second glass background behind our button.
 SEL hide=NSSelectorFromString(@"setHidesSharedBackground:");
 if([item respondsToSelector:hide])((void(*)(id,SEL,BOOL))objc_msgSend)(item,hide,YES);
 return item;
}
