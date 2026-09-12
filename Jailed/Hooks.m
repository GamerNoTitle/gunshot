#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../UI/GSPanel.h"

// Independent Objective-C hooks: no Substrate / ElleKit dependency for IPA injection.
static void (*GSOriginalKeyWindow)(UIWindow *, SEL);
static id (*GSOriginalActivityInit)(id, SEL, NSArray *, NSArray *);
static void GSKeyWindow(UIWindow *window, SEL selector) {
 GSOriginalKeyWindow(window, selector);
 GSInstallButton(window);
}
static id GSActivityInit(id object, SEL selector, NSArray *items, NSArray *activities) {
 NSMutableArray *all=activities?[activities mutableCopy]:[NSMutableArray array];
 GSUploadActivity *upload=[GSUploadActivity new];
 if([upload canPerformWithActivityItems:items])[all addObject:upload];
 return GSOriginalActivityInit(object,selector,items,all);
}
__attribute__((constructor)) static void GSLoadJailed(void) {
 @autoreleasepool {
 // LC's guest bundle is resolved lazily on the main queue, after guest setup.
 dispatch_async(dispatch_get_main_queue(),^{
 NSString *executable=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"];
 if(![executable isEqualToString:@"GooglePhotos"])return;
 Method key=class_getInstanceMethod(UIWindow.class,@selector(becomeKeyWindow));
 Method activity=class_getInstanceMethod(UIActivityViewController.class,@selector(initWithActivityItems:applicationActivities:));
 GSOriginalKeyWindow=(void *)method_setImplementation(key,(IMP)GSKeyWindow);
 GSOriginalActivityInit=(void *)method_setImplementation(activity,(IMP)GSActivityInit);
 // Also covers LiveContainer loaders that inject after the first key window.
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
  if([scene isKindOfClass:UIWindowScene.class])
   for(UIWindow *window in ((UIWindowScene *)scene).windows)if(window.isKeyWindow)GSInstallButton(window);
 });
 }
}
