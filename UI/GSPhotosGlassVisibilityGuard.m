#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static IMP GSOriginalSetTabBarHiddenAnimated;
static IMP GSOriginalSetTabBarIsHidden;
static BOOL GSVisibilityGuardInstalled;

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

static BOOL GSPhotosControllerReportsHidden(UIViewController *controller){
 if(!controller)return NO;
 SEL selector=NSSelectorFromString(@"tabBarIsHidden");
 if(![controller respondsToSelector:selector])return NO;
 return ((BOOL(*)(id,SEL))objc_msgSend)(controller,selector);
}

static UIWindow *GSPhotosHostWindow(UIWindowScene *scene,UIViewController **tabControllerOut){
 if(tabControllerOut)*tabControllerOut=nil;
 for(UIWindow *window in scene.windows){
  if(GSIsPhotosGlassOverlayWindow(window)||!window.rootViewController)continue;
  UIViewController *tabs=GSFindPhotosTabController(window.rootViewController);
  if(!tabs)continue;
  if(tabControllerOut)*tabControllerOut=tabs;
  return window;
 }
 return nil;
}

static BOOL GSSceneHasForeignKeyWindow(UIWindowScene *scene,UIWindow *hostWindow){
 for(UIWindow *window in scene.windows){
  if(window==hostWindow||GSIsPhotosGlassOverlayWindow(window)||window.hidden||window.alpha<=0.01||!window.rootViewController)continue;
  if(window.isKeyWindow)return YES;
 }
 return NO;
}

static BOOL GSSceneShouldMaskNativeTabs(UIWindowScene *scene){
 UIViewController *tabs=nil;UIWindow *hostWindow=GSPhotosHostWindow(scene,&tabs);
 if(!hostWindow||!tabs)return YES;
 if(GSPhotosControllerReportsHidden(tabs))return YES;
 if(GSSceneHasForeignKeyWindow(scene,hostWindow))return YES;
 return NO;
}

static void GSApplySceneMask(UIWindowScene *scene){
 BOOL masked=GSSceneShouldMaskNativeTabs(scene);
 for(UIWindow *window in scene.windows){
  if(!GSIsPhotosGlassOverlayWindow(window))continue;
  window.alpha=masked?0.0:1.0;
 }
}

static void GSRefreshAllScenes(void){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSRefreshAllScenes();});return;}
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
  if([scene isKindOfClass:UIWindowScene.class])GSApplySceneMask((UIWindowScene *)scene);
 }
}

static void GSScheduleVisibilityRefreshes(void){
 GSRefreshAllScenes();
 for(NSNumber *delay in @[@0.05,@0.20,@0.50]){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{GSRefreshAllScenes();});
 }
}

static void GSSetTabBarHiddenAnimated(id controller,SEL selector,BOOL hidden,BOOL animated){
 if(hidden){
  UIViewController *viewController=[controller isKindOfClass:UIViewController.class]?controller:nil;
  UIWindowScene *scene=viewController.viewIfLoaded.window.windowScene;
  if(scene){
   for(UIWindow *window in scene.windows)if(GSIsPhotosGlassOverlayWindow(window))window.alpha=0.0;
  }
 }
 ((void(*)(id,SEL,BOOL,BOOL))GSOriginalSetTabBarHiddenAnimated)(controller,selector,hidden,animated);
 GSScheduleVisibilityRefreshes();
}

static void GSSetTabBarIsHidden(id controller,SEL selector,BOOL hidden){
 if(hidden){
  UIViewController *viewController=[controller isKindOfClass:UIViewController.class]?controller:nil;
  UIWindowScene *scene=viewController.viewIfLoaded.window.windowScene;
  if(scene){
   for(UIWindow *window in scene.windows)if(GSIsPhotosGlassOverlayWindow(window))window.alpha=0.0;
  }
 }
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
 if(animatedMethod&&method_getNumberOfArguments(animatedMethod)==4){
  GSOriginalSetTabBarHiddenAnimated=GSHookOwnOrInheritedMethod(cls,animatedSelector,(IMP)GSSetTabBarHiddenAnimated);
 }
 SEL propertySelector=NSSelectorFromString(@"setTabBarIsHidden:");
 Method propertyMethod=class_getInstanceMethod(cls,propertySelector);
 if(propertyMethod&&method_getNumberOfArguments(propertyMethod)==3){
  GSOriginalSetTabBarIsHidden=GSHookOwnOrInheritedMethod(cls,propertySelector,(IMP)GSSetTabBarIsHidden);
 }
 GSVisibilityGuardInstalled=YES;
 GSScheduleVisibilityRefreshes();
}

__attribute__((constructor)) static void GSLoadPhotosGlassVisibilityGuard(void){
 @autoreleasepool{
  if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.google.Photos"]&&
     ![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"])return;
  NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
  for(NSNotificationName name in @[UIWindowDidBecomeKeyNotification,UIWindowDidResignKeyNotification,UIWindowDidBecomeVisibleNotification,UIWindowDidBecomeHiddenNotification,UIApplicationDidBecomeActiveNotification]){
   [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){(void)note;GSScheduleVisibilityRefreshes();}];
  }
  dispatch_async(dispatch_get_main_queue(),^{GSInstallVisibilityGuard();});
 }
}
