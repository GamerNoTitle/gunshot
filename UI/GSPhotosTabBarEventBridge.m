#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

// GSPhotosGlass intentionally uses a real iOS 26 UITabBar for the visible
// navigation chrome. Google Photos 7.92 builds differ in whether
// setSelectedSegmentIndex: also emits UIControlEventValueChanged, so bridge the
// delegate without assuming either behavior. This keeps the system-owned
// UITabBar interaction/lensing intact while guaranteeing exactly one navigation
// event for a changed tab.
@interface GSPhotosGlassValueChangeProbe : NSObject
@property(nonatomic) BOOL fired;
- (void)valueChanged:(id)sender;
@end

@implementation GSPhotosGlassValueChangeProbe
- (void)valueChanged:(id)sender{self.fired=YES;}
@end

static IMP GSPhotosGlassOriginalTabDidSelect;

static void GSPhotosGlassTabDidSelect(id pair,SEL selector,UITabBar *tabBar,UITabBarItem *item){
 SEL segmentsSelector=NSSelectorFromString(@"segments");
 id segments=[pair respondsToSelector:segmentsSelector]?((id(*)(id,SEL))objc_msgSend)(pair,segmentsSelector):nil;
 BOOL canObserve=[segments isKindOfClass:UIControl.class]&&[segments respondsToSelector:NSSelectorFromString(@"selectedSegmentIndex")];
 NSInteger before=NSNotFound;
 GSPhotosGlassValueChangeProbe *probe=nil;
 if(canObserve){
  before=((NSInteger(*)(id,SEL))objc_msgSend)(segments,NSSelectorFromString(@"selectedSegmentIndex"));
  probe=[GSPhotosGlassValueChangeProbe new];
  [(UIControl *)segments addTarget:probe action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
 }

 ((void(*)(id,SEL,UITabBar *,UITabBarItem *))GSPhotosGlassOriginalTabDidSelect)(pair,selector,tabBar,item);

 if(!probe)return;
 [(UIControl *)segments removeTarget:probe action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
 NSInteger after=((NSInteger(*)(id,SEL))objc_msgSend)(segments,NSSelectorFromString(@"selectedSegmentIndex"));
 if(before!=after&&after==item.tag&&!probe.fired)
  [(UIControl *)segments sendActionsForControlEvents:UIControlEventValueChanged];
}

__attribute__((constructor)) static void GSInstallPhotosGlassTabEventBridge(void){
 Class pairClass=NSClassFromString(@"GSPhotosGlassPair");
 SEL selector=@selector(tabBar:didSelectItem:);
 Method method=pairClass?class_getInstanceMethod(pairClass,selector):NULL;
 if(!method)return;
 GSPhotosGlassOriginalTabDidSelect=method_getImplementation(method);
 method_setImplementation(method,(IMP)GSPhotosGlassTabDidSelect);
}
