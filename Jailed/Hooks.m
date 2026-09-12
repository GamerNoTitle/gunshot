#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../UI/GSPanel.h"
#import "../UI/GSAccountMenu.h"
#import "../UI/GSNativeRouting.h"

// Independent Objective-C hooks: no Substrate / ElleKit dependency for IPA injection.
static id (*GSOriginalActivityInit)(id, SEL, NSArray *, NSArray *);
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
 GSInstallAccountMenu();GSInstallNativeRouting();
 Method activity=class_getInstanceMethod(UIActivityViewController.class,@selector(initWithActivityItems:applicationActivities:));
 if(activity)GSOriginalActivityInit=(void *)method_setImplementation(activity,(IMP)GSActivityInit);
 });
 }
}
