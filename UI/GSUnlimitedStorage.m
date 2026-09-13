#import "GSUnlimitedStorage.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

static NSString *const GSStoragePreference=@"GSShowUnlimitedStorage";
// Presentation enum verified in Google Photos 7.92.0. Never change GMUQuota.
static const NSInteger GSNativeUnlimitedState=2;
static BOOL GSStorageInstalled;
static id (*GSOriginalStorageData)(id,SEL);
static id (*GSOriginalStorageTitle)(id,SEL,id);
static NSBundle *GSStorageStrings;

BOOL GSUnlimitedStorageEnabled(void){
 id value=[NSUserDefaults.standardUserDefaults objectForKey:GSStoragePreference];
 return value==nil?YES:[value boolValue];
}
void GSSetUnlimitedStorage(BOOL enabled){[NSUserDefaults.standardUserDefaults setBool:enabled forKey:GSStoragePreference];}
BOOL GSUnlimitedStorageAvailable(void){return GSStorageInstalled;}
static BOOL GSStorageMethod(Class cls,NSString *name,const char *encoding){
 Method method=class_getInstanceMethod(cls,NSSelectorFromString(name));
 return method&&!strcmp(method_getTypeEncoding(method),encoding);
}
static NSString *GSUnlimitedTitle(void){
 NSString *key=@"OneGoogleStorageCardUnlimitedTitle";
 NSString *title=[GSStorageStrings localizedStringForKey:key value:@"" table:@"OneGoogle"];
 return title.length&&![title isEqual:key]?title:nil;
}
static id GSStorageData(id object,SEL selector){
 // The audited original allocates a fresh OGLAccountMenuStorageCardData on
 // every call. It is a menu presentation model, not the account's quota model.
 id data=GSOriginalStorageData(object,selector);
 if(!GSUnlimitedStorageEnabled()||object_getClass(data)!=NSClassFromString(@"OGLAccountMenuStorageCardData"))return data;
 NSString *title=GSUnlimitedTitle();if(!title)return data;
 ((void(*)(id,SEL,NSInteger))objc_msgSend)(data,NSSelectorFromString(@"setStorageState:"),GSNativeUnlimitedState);
 ((void(*)(id,SEL,id))objc_msgSend)(data,NSSelectorFromString(@"setTitle:"),title);
 // Native state 2 supplies the localized unlimited subtitle itself.
 ((void(*)(id,SEL,id))objc_msgSend)(data,NSSelectorFromString(@"setSubtitle:"),nil);
 return data;
}
static id GSStorageTitle(id cls,SEL selector,id item){
 // The 7.92.0 legacy card formatter still uses a regular/percentage title in
 // state 2. Feed its native unlimited resource to the native title label;
 // height calculation and updateCardState both use this same formatter.
 if(GSUnlimitedStorageEnabled()&&object_getClass(item)==NSClassFromString(@"OGLAccountSelectorStorageCardItem")&&
    ((NSInteger(*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"storageState"))==GSNativeUnlimitedState){
  NSString *title=GSUnlimitedTitle();if(title)return title;
 }
 return GSOriginalStorageTitle(cls,selector,item);
}
void GSInstallUnlimitedStorage(void){
 if(GSStorageInstalled||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"]||
    ![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqual:@"7.92.0"])return;
 Class source=NSClassFromString(@"PHSMyAccountMenuDataSource"),data=NSClassFromString(@"OGLAccountMenuStorageCardData");
 Class item=NSClassFromString(@"OGLAccountSelectorStorageCardItem"),cell=NSClassFromString(@"OGLAccountSelectorStorageCardCell");
 if(!GSStorageMethod(source,@"storageCardData","@16@0:8")||
    !GSStorageMethod(data,@"setStorageState:","v24@0:8q16")||
    !GSStorageMethod(data,@"setTitle:","v24@0:8@16")||
    !GSStorageMethod(data,@"setSubtitle:","v24@0:8@16")||
    !GSStorageMethod(item,@"storageState","q16@0:8")||
    !GSStorageMethod(object_getClass(cell),@"titleTextWithStorageItem:","@24@0:8@16"))return;
 NSURL *url=[[NSBundle bundleForClass:data]URLForResource:@"OneGoogle" withExtension:@"bundle"];
 GSStorageStrings=url?[NSBundle bundleWithURL:url]:nil;
 if(!GSUnlimitedTitle())return; // No fabricated translation or overlay fallback.
 GSOriginalStorageData=(void *)method_setImplementation(class_getInstanceMethod(source,NSSelectorFromString(@"storageCardData")),(IMP)GSStorageData);
 GSOriginalStorageTitle=(void *)method_setImplementation(class_getClassMethod(cell,NSSelectorFromString(@"titleTextWithStorageItem:")),(IMP)GSStorageTitle);
 GSStorageInstalled=YES;
}
