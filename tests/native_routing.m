#import "../UI/GSNativeRouting.h"
#import <objc/runtime.h>
#include <assert.h>

static NSString *version=@"unsupported";
@interface GSFixtureBundle : NSBundle
@end
@implementation GSFixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
 if([key isEqual:@"CFBundleExecutable"])return @"GooglePhotos";
 if([key isEqual:@"CFBundleShortVersionString"])return version;
 return nil;
}
@end
static NSBundle *FixtureMainBundle(id object,SEL selector){static GSFixtureBundle *b; if(!b)b=[GSFixtureBundle new];return b;}
@implementation PHAsset
@end
@interface PHSLocalAsset : NSObject
@property(nonatomic,strong) PHAsset *phAsset;
@property(nonatomic) _Bool isLocked;
@end
@implementation PHSLocalAsset
@end
static NSUInteger originalCount,routedCount,lastCount;
static NSString *lastAccount;
@interface PHSBackupActionBehaviorImpl : NSObject
- (void)backupLocalAssets:(id)assets;
@end
@implementation PHSBackupActionBehaviorImpl
- (void)backupLocalAssets:(id)assets{originalCount++;}
@end
@interface PHSActionsGridModel : NSObject
- (void)backupLocalAssets:(id)assets;
@end
@implementation PHSActionsGridModel
- (void)backupLocalAssets:(id)assets{originalCount++;}
@end
void GSPresentRoutedAssets(NSArray<PHAsset *> *assets,NSString *account){routedCount++;lastCount=assets.count;lastAccount=account;}
static void Drain(NSUInteger expected){
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:2];
 while(routedCount<expected&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 assert(routedCount==expected);
}
int main(void){@autoreleasepool{
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)FixtureMainBundle);
 GSInstallNativeRouting();assert(!GSNativeRoutingAvailable());
 version=@"7.92.0";GSInstallNativeRouting();assert(GSNativeRoutingAvailable());
 GSSetNativeRouting(NO,nil);
 PHSBackupActionBehaviorImpl *behavior=[PHSBackupActionBehaviorImpl new];
 PHSActionsGridModel *grid=[PHSActionsGridModel new];
 PHSLocalAsset *local=[PHSLocalAsset new];local.phAsset=[PHAsset new];
 [behavior backupLocalAssets:@[local]];[grid backupLocalAssets:@[local]];
 assert(originalCount==2&&routedCount==0);
 GSSetNativeRouting(YES,@"destination@example.com");
 [behavior backupLocalAssets:@[local]];Drain(1);
 assert(lastCount==1&&originalCount==2&&[lastAccount isEqual:@"destination@example.com"]);
 [grid backupLocalAssets:[NSSet setWithObjects:local.phAsset,[PHAsset new],nil]];Drain(2);
 assert(lastCount==2&&originalCount==2);
 [behavior backupLocalAssets:@[local,@"unknown"]];Drain(3);
 assert(lastCount==0&&originalCount==2); // No partial handoff / no native fallback.
 local.isLocked=YES;[grid backupLocalAssets:@[local]];Drain(4);
 assert(lastCount==0&&originalCount==2);
 GSSetNativeRouting(NO,nil);[behavior backupLocalAssets:@[local]];
 assert(originalCount==3&&routedCount==4);
 return 0;
}}
