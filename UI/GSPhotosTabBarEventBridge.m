#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

// GSPhotosGlass uses a real UITabBarController so UIKit owns the iOS 26
// floating platter, selected lens and press interaction. Google Photos 7.92
// builds differ in whether setSelectedSegmentIndex: also emits ValueChanged, so
// bridge the controller delegate without assuming either behavior.
@interface GSPhotosGlassValueChangeProbe : NSObject
@property(nonatomic) BOOL fired;
- (void)valueChanged:(id)sender;
@end

@implementation GSPhotosGlassValueChangeProbe
- (void)valueChanged:(id)sender{self.fired=YES;}
@end

static IMP GSPhotosGlassOriginalTabControllerDidSelect;

static void GSPhotosGlassTabControllerDidSelect(id pair,SEL selector,UITabBarController *tabController,UIViewController *viewController){
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

 ((void(*)(id,SEL,UITabBarController *,UIViewController *))GSPhotosGlassOriginalTabControllerDidSelect)(pair,selector,tabController,viewController);

 if(!probe)return;
 [(UIControl *)segments removeTarget:probe action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
 NSInteger after=((NSInteger(*)(id,SEL))objc_msgSend)(segments,NSSelectorFromString(@"selectedSegmentIndex"));
 if(before!=after&&after==(NSInteger)tabController.selectedIndex&&!probe.fired)
  [(UIControl *)segments sendActionsForControlEvents:UIControlEventValueChanged];
}

__attribute__((constructor)) static void GSInstallPhotosGlassTabEventBridge(void){
 Class pairClass=NSClassFromString(@"GSPhotosGlassPair");
 SEL selector=@selector(tabBarController:didSelectViewController:);
 Method method=pairClass?class_getInstanceMethod(pairClass,selector):NULL;
 if(!method)return;
 GSPhotosGlassOriginalTabControllerDidSelect=method_getImplementation(method);
 method_setImplementation(method,(IMP)GSPhotosGlassTabControllerDidSelect);
}
