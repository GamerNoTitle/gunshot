#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static IMP GSOriginalSetTabBarHiddenAnimated;
static IMP GSOriginalSetTabBarIsHidden;
static BOOL GSVisibilityGuardInstalled;
static char GSExplicitHiddenStateKey;

static BOOL GSIsPhotosGlassOverlayWindow(UIWindow *window){
 if(!window)return NO;
 return [NSStringFromClass(window.class)isEqualToString:@"GSPhotosGlassOverlayWindow"]&&
        [window.rootViewController isKindOfClass:UITabBarController.class];
}

static UIViewController *GSFindPhotosTabController(UIViewController *controller){
 if(!controller)return nil;
 Class cls=NSClassFromString(@"PHSTabBarController");
 if(cls&&[controller isKindOfClass:cls])return controller;
 for(UIViewController *child in controller.childViewControllers){
  UIViewController *match=GSFindPhotosTabController(child);if(match)return match;
 }
 UIViewController *presented=controller.presentedViewController;
 if(presented&&!presented.isBeingDismissed){
  UIViewController *match=GSFindPhotosTabController(presented);if(match)return match;
 }
 return nil;
}

static UIWindow *GSPhotosHostWindow(UIWindowScene *scene,UIViewController **tabControllerOut){
 if(tabControllerOut)*tabControllerOut=nil;
 UIWindow *fallback=nil;UIViewController *fallbackTabs=nil;
 for(UIWindow *window in scene.windows){
  if(GSIsPhotosGlassOverlayWindow(window)||!window.rootViewController||window.hidden||window.alpha<=0.01)continue;
  UIViewController *tabs=GSFindPhotosTabController(window.rootViewController);
  if(!tabs)continue;
  if(window.isKeyWindow){if(tabControllerOut)*tabControllerOut=tabs;return window;}
  if(!fallback){fallback=window;fallbackTabs=tabs;}
 }
 if(tabControllerOut)*tabControllerOut=fallbackTabs;
 return fallback;
}

static void GSSetExplicitHidden(id controller,BOOL hidden){
 if(!controller)return;
 objc_setAssociatedObject(controller,&GSExplicitHiddenStateKey,@(hidden),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL GSExplicitlyHidden(id controller){
 NSNumber *value=controller?objc_getAssociatedObject(controller,&GSExplicitHiddenStateKey):nil;
 return value.boolValue;
}

static UIWindow *GSGlassOverlayWindow(UIWindowScene *scene){
 for(UIWindow *window in scene.windows)if(GSIsPhotosGlassOverlayWindow(window))return window;
 return nil;
}

static BOOL GSWindowActuallyCoversNativeTabs(UIWindow *candidate,UIWindow *hostWindow,UIWindow *overlayWindow){
 if(!candidate||candidate==hostWindow||candidate==overlayWindow||candidate.hidden||candidate.alpha<=0.01||!candidate.rootViewController)return NO;
 if(candidate.windowLevel<hostWindow.windowLevel)return NO;
 // Ignore high-level system helper windows (status/text effects/etc.). Google Photos'
 // own full-screen/menu windows stay at or near the app's normal level.
 if(candidate.windowLevel>hostWindow.windowLevel+10.0)return NO;
 if(candidate.windowLevel==hostWindow.windowLevel&&!candidate.isKeyWindow)return NO;
 UITabBarController *tabs=[overlayWindow.rootViewController isKindOfClass:UITabBarController.class]?(UITabBarController *)overlayWindow.rootViewController:nil;
 UITabBar *tabBar=tabs.tabBar;
 if(!tabBar||tabBar.hidden||tabBar.alpha<=0.01||!tabBar.window)return NO;
 CGRect tabRect=[tabBar convertRect:tabBar.bounds toView:overlayWindow];
 if(CGRectIsNull(tabRect)||CGRectIsEmpty(tabRect))return NO;
 CGFloat y=CGRectGetMidY(tabRect);
 CGFloat xs[]={CGRectGetMinX(tabRect)+CGRectGetWidth(tabRect)*0.15,
              CGRectGetMidX(tabRect),
              CGRectGetMinX(tabRect)+CGRectGetWidth(tabRect)*0.85};
 for(NSUInteger i=0;i<3;i++){
  CGPoint overlayPoint=CGPointMake(xs[i],y);
  CGPoint screenPoint=[overlayWindow convertPoint:overlayPoint toWindow:nil];
  CGPoint candidatePoint=[candidate convertPoint:screenPoint fromWindow:nil];
  if(!CGRectContainsPoint(candidate.bounds,candidatePoint))continue;
  UIView *hit=[candidate hitTest:candidatePoint withEvent:nil];
  if(hit&&hit.window==candidate)return YES;
 }
 return NO;
}

static BOOL GSSceneHasOccludingWindow(UIWindowScene *scene,UIWindow *hostWindow,UIWindow *overlayWindow){
 for(UIWindow *window in scene.windows)
  if(GSWindowActuallyCoversNativeTabs(window,hostWindow,overlayWindow))return YES;
 return NO;
}

static BOOL GSSceneShouldMaskNativeTabs(UIWindowScene *scene,UIWindow *overlayWindow){
 UIViewController *tabs=nil;UIWindow *hostWindow=GSPhotosHostWindow(scene,&tabs);
 // This guard only adds positive suppression. If discovery is temporarily
 // incomplete, leave visibility to GSPhotosGlass.m instead of hiding everything.
 if(!hostWindow||!tabs)return NO;
 if(GSExplicitlyHidden(tabs))return YES;
 if(GSSceneHasOccludingWindow(scene,hostWindow,overlayWindow))return YES;
 return NO;
}

static void GSApplySceneMask(UIWindowScene *scene){
 UIWindow *overlayWindow=GSGlassOverlayWindow(scene);if(!overlayWindow)return;
 overlayWindow.alpha=GSSceneShouldMaskNativeTabs(scene,overlayWindow)?0.0:1.0;
}

static void GSRefreshAllScenes(void){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSRefreshAllScenes();});return;}
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
  if([scene isKindOfClass:UIWindowScene.class])GSApplySceneMask((UIWindowScene *)scene);
}

static void GSScheduleVisibilityRefreshes(void){
 GSRefreshAllScenes();
 for(NSNumber *delay in @[@0.05,@0.20,@0.50])
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{GSRefreshAllScenes();});
}

static void GSMaskSceneNowForController(id controller){
 UIViewController *viewController=[controller isKindOfClass:UIViewController.class]?controller:nil;
 UIWindowScene *scene=viewController.viewIfLoaded.window.windowScene;
 if(!scene)return;
 for(UIWindow *window in scene.windows)if(GSIsPhotosGlassOverlayWindow(window))window.alpha=0.0;
}

static void GSSetTabBarHiddenAnimated(id controller,SEL selector,BOOL hidden,BOOL animated){
 GSSetExplicitHidden(controller,hidden);
 if(hidden)GSMaskSceneNowForController(controller);
 ((void(*)(id,SEL,BOOL,BOOL))GSOriginalSetTabBarHiddenAnimated)(controller,selector,hidden,animated);
 GSScheduleVisibilityRefreshes();
}

static void GSSetTabBarIsHidden(id controller,SEL selector,BOOL hidden){
 GSSetExplicitHidden(controller,hidden);
 if(hidden)GSMaskSceneNowForController(controller);
 ((void(*)(id,SEL,BOOL))GSOriginalSetTabBarIsHidden)(controller,selector,hidden);
 GSScheduleVisibilityRefreshes();
}

static IMP GSHookOwnOrInheritedMethod(Class cls,SEL selector,IMP replacement){
 Method method=class_getInstanceMethod(cls,selector);if(!method)return NULL;
 IMP current=method_getImplementation(method);
 IMP replaced=class_replaceMethod(cls,selector,replacement,method_getTypeEncoding(method));
 return replaced?:current;
}

static void GSInstallVisibilityGuard(void){
 if(GSVisibilityGuardInstalled)return;
 Class cls=NSClassFromString(@"PHSTabBarController");if(!cls)return;
 SEL animatedSelector=NSSelectorFromString(@"setTabBarHidden:animated:");
 Method animatedMethod=class_getInstanceMethod(cls,animatedSelector);
 if(animatedMethod&&method_getNumberOfArguments(animatedMethod)==4)
  GSOriginalSetTabBarHiddenAnimated=GSHookOwnOrInheritedMethod(cls,animatedSelector,(IMP)GSSetTabBarHiddenAnimated);
 SEL propertySelector=NSSelectorFromString(@"setTabBarIsHidden:");
 Method propertyMethod=class_getInstanceMethod(cls,propertySelector);
 if(propertyMethod&&method_getNumberOfArguments(propertyMethod)==3)
  GSOriginalSetTabBarIsHidden=GSHookOwnOrInheritedMethod(cls,propertySelector,(IMP)GSSetTabBarIsHidden);
 GSVisibilityGuardInstalled=YES;
 GSScheduleVisibilityRefreshes();
}

__attribute__((constructor)) static void GSLoadPhotosGlassVisibilityGuard(void){
 @autoreleasepool{
  if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.google.Photos"]&&
     ![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"])return;
  NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
  for(NSNotificationName name in @[UIWindowDidBecomeKeyNotification,UIWindowDidResignKeyNotification,UIWindowDidBecomeVisibleNotification,UIWindowDidBecomeHiddenNotification,UIApplicationDidBecomeActiveNotification])
   [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){(void)note;GSScheduleVisibilityRefreshes();}];
  dispatch_async(dispatch_get_main_queue(),^{GSInstallVisibilityGuard();});
 }
}
