#import "../UI/GSUnlimitedStorage.h"
#import <objc/runtime.h>
#include <assert.h>

static NSString *Version=@"unsupported",*Executable=@"GooglePhotos";
static NSBundle *Resources;
static NSUInteger Calls,Actions,TitleCalls;
@interface GSStorageFixtureBundle : NSObject @end
@implementation GSStorageFixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?Executable:Version;}
@end
static id MainBundle(id object,SEL selector){static id bundle;if(!bundle)bundle=[GSStorageFixtureBundle new];return bundle;}
static id BundleForClass(id object,SEL selector,Class cls){return Resources;}
@interface OGLAccountMenuStorageCardData : NSObject
@property(nonatomic) NSInteger storageState;
@property(nonatomic,copy) NSString *title,*subtitle;
@property(nonatomic) double usedStorage,totalStorage;
@property(nonatomic,copy) void(^cardActionCallback)(void);
@end
@implementation OGLAccountMenuStorageCardData @end
@interface OGLAccountSelectorStorageCardItem : NSObject
@property(nonatomic) NSInteger storageState;
@end
@implementation OGLAccountSelectorStorageCardItem @end
@interface OGLAccountSelectorStorageCardCell : NSObject
+ (id)titleTextWithStorageItem:(id)item;
@end
@implementation OGLAccountSelectorStorageCardCell
+ (id)titleTextWithStorageItem:(id)item{TitleCalls++;return @"Native regular title";}
@end
@interface GSStorageFixtureSource : NSObject
@property(nonatomic) BOOL empty;
@property(nonatomic,strong) id replacement;
@property(nonatomic) NSInteger quotaState;
- (id)storageCardData;
@end
@implementation GSStorageFixtureSource
- (id)storageCardData{
 Calls++;if(self.empty)return nil;if(self.replacement)return self.replacement;
 OGLAccountMenuStorageCardData *data=[OGLAccountMenuStorageCardData new];
 data.storageState=self.quotaState;data.title=@"Original title";data.subtitle=@"Original subtitle";
 data.usedStorage=8;data.totalStorage=15;data.cardActionCallback=^{Actions++;};return data;
}
@end
int main(int argc,const char **argv){@autoreleasepool{
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 assert(GSUnlimitedStorageEnabled());GSSetUnlimitedStorage(NO);assert(!GSUnlimitedStorageEnabled());
 GSSetUnlimitedStorage(YES);assert(GSUnlimitedStorageEnabled());
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)MainBundle);
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(bundleForClass:)),(IMP)BundleForClass);
 Class sourceClass=objc_allocateClassPair(GSStorageFixtureSource.class,"PHSMyAccountMenuDataSource",0);
 if(argc>1)class_addMethod(sourceClass,@selector(storageCardData),class_getMethodImplementation(GSStorageFixtureSource.class,@selector(storageCardData)),"q16@0:8");
 objc_registerClassPair(sourceClass);
 GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Version=@"7.92.0";Executable=@"OtherApp";GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Executable=@"GooglePhotos";GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable()); // Missing bundle.
 NSString *root=[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
 NSString *bundle=[root stringByAppendingPathComponent:@"OneGoogle.bundle"];
 [[NSFileManager defaultManager]createDirectoryAtPath:bundle withIntermediateDirectories:YES attributes:nil error:nil];
 [@{@"OneGoogleStorageCardUnlimitedTitle":@"Unlimited storage"}writeToFile:[bundle stringByAppendingPathComponent:@"OneGoogle.strings"] atomically:YES];
 [@{@"CFBundleIdentifier":@"dev.tqmane.storagefixture",@"CFBundlePackageType":@"BNDL"}writeToFile:[bundle stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
 [@{@"CFBundleIdentifier":@"dev.tqmane.storageparent",@"CFBundlePackageType":@"BNDL"}writeToFile:[root stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
 Resources=[NSBundle bundleWithPath:root];assert(Resources);
 if(argc>1){
  // Run in a fresh process: a changed private ABI must leave both IMPs intact.
  GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 }else{
  GSInstallUnlimitedStorage();assert(GSUnlimitedStorageAvailable());GSInstallUnlimitedStorage();
  GSStorageFixtureSource *source=[sourceClass new];
  OGLAccountMenuStorageCardData *data=[source storageCardData];assert(Calls==1&&data.storageState==2);
  assert([data.title isEqual:@"Unlimited storage"]&&data.subtitle==nil);
  assert(data.usedStorage==8&&data.totalStorage==15&&source.quotaState==0);
  data.cardActionCallback();assert(Actions==1);
  OGLAccountSelectorStorageCardItem *item=[OGLAccountSelectorStorageCardItem new];item.storageState=2;
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Unlimited storage"]);
  item.storageState=0;assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native regular title"]&&TitleCalls==1);
  GSSetUnlimitedStorage(NO);OGLAccountMenuStorageCardData *normal=[source storageCardData];
  assert(normal!=data&&normal.storageState==0&&[normal.title isEqual:@"Original title"]&&[normal.subtitle isEqual:@"Original subtitle"]);
  assert(data.storageState==2); // No retroactive mutation of a previous menu.
  item.storageState=2;assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native regular title"]);
  GSSetUnlimitedStorage(YES);assert([[source storageCardData]storageState]==2);
  source.empty=YES;assert([source storageCardData]==nil);source.empty=NO;
  source.replacement=[NSObject new];assert([source storageCardData]==source.replacement);
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:nil]isEqual:@"Native regular title"]);
 }
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 [[NSFileManager defaultManager]removeItemAtPath:root error:nil];
 NSLog(@"PASS native unlimited storage presentation");
}}
