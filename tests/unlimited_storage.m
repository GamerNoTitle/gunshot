#import "../UI/GSUnlimitedStorage.h"
#import <objc/runtime.h>
#include <assert.h>

static NSString *Version=@"unsupported",*Executable=@"GooglePhotos";
static BOOL ResourcesReady;
static NSUInteger Calls,Actions,TitleCalls,ResourceCalls;
@interface GSStorageFixtureBundle : NSObject @end
@implementation GSStorageFixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?Executable:Version;}
@end
static id MainBundle(id object,SEL selector){static id bundle;if(!bundle)bundle=[GSStorageFixtureBundle new];return bundle;}
// Actual native resource API, including its int (not NSInteger) string ID ABI.
@interface OGLStringResources : NSObject
+ (id)sharedInstance;
- (id)stringForID:(int)identifier;
@end
@implementation OGLStringResources
+ (id)sharedInstance{static id resources;if(!resources)resources=[self new];return resources;}
- (id)stringForID:(int)identifier{assert(identifier==0x81);ResourceCalls++;return ResourcesReady?@"Unlimited storage":@"OneGoogleStorageCardUnlimitedTitle";}
@end
// Google Photos 7.92.0's stored card properties, including all native actions.
@interface OGLAccountMenuStorageCardData : NSObject
@property(nonatomic) NSUInteger dataMode;
@property(nonatomic) NSInteger storageState,iconType;
@property(nonatomic,copy) NSString *title,*subtitle,*backupStoppedReason,*manageStorageButtonLabel,*secondActionButtonLabel;
@property(nonatomic) double usedStorage,totalStorage;
@property(nonatomic) BOOL recalculatingStorage,invokeSecondActionForCell,showActionWithoutUsageThreshold,showOrganizationOutOfStorageCard,isTrailingPrimaryAction;
@property(nonatomic,copy) void(^cardActionCallback)(void),(^cardSecondActionCallback)(void),(^cardTapActionCallBack)(void);
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
@property(nonatomic,strong) id data;
- (id)storageCardData;
@end
@implementation GSStorageFixtureSource
- (id)storageCardData{Calls++;return self.data;}
@end
@interface GSStorageFixtureAggregate : NSObject
@property(nonatomic,strong) id cards;
- (id)accountMenuCardData;
@end
@implementation GSStorageFixtureAggregate
// Models the self-managed path: never calls Photos.storageCardData at all.
- (id)accountMenuCardData{return self.cards;}
@end
static OGLAccountMenuStorageCardData *Card(void){
 OGLAccountMenuStorageCardData *data=[OGLAccountMenuStorageCardData new];
 data.dataMode=7;data.iconType=3;data.storageState=0;data.title=@"43% of 15 GB used";data.subtitle=@"Original subtitle";
 data.usedStorage=6.55;data.totalStorage=15;data.recalculatingStorage=YES;
 data.invokeSecondActionForCell=YES;data.showActionWithoutUsageThreshold=YES;
 data.showOrganizationOutOfStorageCard=YES;data.isTrailingPrimaryAction=YES;
 data.backupStoppedReason=@"fixture-reason";data.manageStorageButtonLabel=@"Get storage";data.secondActionButtonLabel=@"Clean up space";
 data.cardActionCallback=^{Actions++;};data.cardSecondActionCallback=^{Actions+=10;};data.cardTapActionCallBack=^{Actions+=100;};return data;
}
static void CheckProjection(OGLAccountMenuStorageCardData *copy,OGLAccountMenuStorageCardData *original){
 assert(copy!=original&&copy.storageState==2&&[copy.title isEqual:@"Unlimited storage"]&&copy.subtitle==nil);
 assert(original.storageState==0&&[original.title isEqual:@"43% of 15 GB used"]&&[original.subtitle isEqual:@"Original subtitle"]);
 assert(copy.usedStorage==original.usedStorage&&copy.totalStorage==original.totalStorage);
 assert(copy.dataMode==7&&copy.iconType==3&&copy.recalculatingStorage&&copy.invokeSecondActionForCell&&copy.showActionWithoutUsageThreshold&&copy.showOrganizationOutOfStorageCard&&copy.isTrailingPrimaryAction);
 assert([copy.backupStoppedReason isEqual:original.backupStoppedReason]&&[copy.manageStorageButtonLabel isEqual:original.manageStorageButtonLabel]&&[copy.secondActionButtonLabel isEqual:original.secondActionButtonLabel]);
 Actions=0;copy.cardActionCallback();copy.cardSecondActionCallback();copy.cardTapActionCallBack();assert(Actions==111);
}
int main(int argc,const char **argv){@autoreleasepool{
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 assert(GSUnlimitedStorageEnabled());GSSetUnlimitedStorage(NO);assert(!GSUnlimitedStorageEnabled());
 GSSetUnlimitedStorage(YES);assert(GSUnlimitedStorageEnabled());
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)MainBundle);
 Class sourceClass=objc_allocateClassPair(GSStorageFixtureSource.class,"PHSMyAccountMenuDataSource",0);
 if(argc>1)class_addMethod(sourceClass,@selector(storageCardData),class_getMethodImplementation(GSStorageFixtureSource.class,@selector(storageCardData)),"q16@0:8");
 objc_registerClassPair(sourceClass);
 Class aggregateClass=objc_allocateClassPair(GSStorageFixtureAggregate.class,"_TtC102googlemac_iPhone_Shared_OneGoogle_AccountSelector_Cards_Implementation_OGLAggregatorCardDataSourceImpl31OGLAggregatorCardDataSourceImpl",0);
 objc_registerClassPair(aggregateClass);
 GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Version=@"7.92.0";Executable=@"OtherApp";GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Executable=@"GooglePhotos";
 if(argc>1){
  GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
  assert([GSUnlimitedStorageSnapshot()[@"status"]isEqual:@"incompatible-source-abi"]);
 }else{
  // Late native resource initialization must not permanently disable the hook.
  GSInstallUnlimitedStorage();assert(GSUnlimitedStorageAvailable());GSInstallUnlimitedStorage();
  GSStorageFixtureAggregate *aggregate=[aggregateClass new];OGLAccountMenuStorageCardData *original=Card();
  NSObject *backup=[NSObject new],*aiCard=[NSObject new];NSArray *cached=@[aiCard,original,backup];aggregate.cards=cached;
  assert([aggregate accountMenuCardData]==cached&&!Calls);
  ResourcesReady=YES;NSArray *shown=[aggregate accountMenuCardData];
  assert(shown!=cached&&shown.count==3&&shown[0]==aiCard&&shown[2]==backup&&!Calls);
  CheckProjection(shown[1],original);
  GSSetUnlimitedStorage(NO);assert([aggregate accountMenuCardData]==cached); // Cached source restores exactly.
  GSSetUnlimitedStorage(YES);CheckProjection([aggregate accountMenuCardData][1],original);
  // Account replacement and an asynchronous server refresh each get a new copy.
  OGLAccountMenuStorageCardData *next=Card();next.usedStorage=1;next.totalStorage=100;aggregate.cards=@[next];
  CheckProjection([aggregate accountMenuCardData][0],next);
  next.usedStorage=2;CheckProjection([aggregate accountMenuCardData][0],next);
  aggregate.cards=@[backup];assert([aggregate accountMenuCardData]==aggregate.cards);
  aggregate.cards=nil;assert([aggregate accountMenuCardData]==nil);
  aggregate.cards=backup;assert([aggregate accountMenuCardData]==backup);
  // Legacy path and inherited base classes remain independent of the aggregator.
  GSStorageFixtureSource *source=[sourceClass new];source.data=original;
  CheckProjection([source storageCardData],original);assert(Calls==1);
  GSStorageFixtureSource *base=[GSStorageFixtureSource new];base.data=original;assert([base storageCardData]==original);
  GSSetUnlimitedStorage(NO);assert([source storageCardData]==original);GSSetUnlimitedStorage(YES);
  source.data=nil;assert([source storageCardData]==nil);source.data=backup;assert([source storageCardData]==backup);
  OGLAccountSelectorStorageCardItem *item=[OGLAccountSelectorStorageCardItem new];item.storageState=2;
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Unlimited storage"]);
  item.storageState=0;assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native regular title"]&&TitleCalls==1);
  GSSetUnlimitedStorage(NO);item.storageState=2;assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native regular title"]);
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:nil]isEqual:@"Native regular title"]);
  NSDictionary *snapshot=GSUnlimitedStorageSnapshot();assert([snapshot[@"aggregateHook"]boolValue]&&[snapshot[@"legacyHook"]boolValue]&&[snapshot[@"projectedCards"]unsignedLongValue]==5&&[snapshot[@"copyFailures"]unsignedLongValue]==0&&ResourceCalls);
  NSSet *keys=[NSSet setWithArray:@[@"available",@"enabled",@"status",@"legacyHook",@"aggregateHook",@"stringsReady",@"legacyCalls",@"aggregateCalls",@"projectedCards",@"copyFailures"]];assert([[NSSet setWithArray:snapshot.allKeys]isEqual:keys]);
 }
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 NSLog(@"PASS native storage aggregation, cached-source restoration, callbacks, late resources and ABI guard");
}}
