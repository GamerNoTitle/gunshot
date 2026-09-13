#import "../UI/GSUnlimitedStorage.h"
#import <objc/runtime.h>
#include <assert.h>

static NSString *Version=@"unsupported",*Executable=@"GooglePhotos";
static BOOL ResourcesReady;
static NSUInteger Actions,TitleCalls,ResourceCalls,CellCalls;
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
@property(nonatomic,strong) OGLAccountMenuStorageCardData *sourceData;
@end
@implementation OGLAccountSelectorStorageCardItem @end
@interface OGLAccountSelectorStorageCardCell : NSObject
+ (id)titleTextWithStorageItem:(id)item;
- (void)updateWithItem:(id)item;
@end
@implementation OGLAccountSelectorStorageCardCell
+ (id)titleTextWithStorageItem:(id)item{TitleCalls++;return @"Native regular title";}
- (void)updateWithItem:(id)item{CellCalls++;}
@end
@interface GSStorageFixtureMapper : NSObject
+ (id)cardItemFromCardData:(id)data;
@end
@implementation GSStorageFixtureMapper
+ (id)cardItemFromCardData:(id)data{
 if(![data isKindOfClass:OGLAccountMenuStorageCardData.class])return data;
 OGLAccountSelectorStorageCardItem *item=[OGLAccountSelectorStorageCardItem new];
 item.storageState=[data storageState];item.sourceData=data;return item;
}
@end
@interface GSStorageObserver : NSObject @end
@implementation GSStorageObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{}
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
 Class mapper=objc_allocateClassPair(GSStorageFixtureMapper.class,"OGLGM2AccountSelectorViewModelItemUtils",0);
 if(argc>1)class_addMethod(object_getClass(mapper),@selector(cardItemFromCardData:),class_getMethodImplementation(object_getClass(GSStorageFixtureMapper.class),@selector(cardItemFromCardData:)),"q24@0:8@16");
 objc_registerClassPair(mapper);
 GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Version=@"7.92.0";Executable=@"OtherApp";GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
 Executable=@"GooglePhotos";
 if(argc>1){
  GSInstallUnlimitedStorage();assert(!GSUnlimitedStorageAvailable());
  assert([GSUnlimitedStorageSnapshot()[@"status"]isEqual:@"incompatible-mapper-abi"]);
 }else{
  // Late native resource initialization must not permanently disable the hook.
  GSInstallUnlimitedStorage();assert(GSUnlimitedStorageAvailable());GSInstallUnlimitedStorage();
  // Neither Photos nor the Swift aggregator fixture exists. Only the actual
  // rendering converter sees these inputs, including a cached source object.
  OGLAccountMenuStorageCardData *original=Card();
  OGLAccountSelectorStorageCardItem *item=[mapper cardItemFromCardData:original];
  assert(item.sourceData==original&&item.storageState==0);
  ResourcesReady=YES;item=[mapper cardItemFromCardData:original];CheckProjection(item.sourceData,original);
  assert(item.storageState==2);
  OGLAccountSelectorStorageCardCell *cell=[OGLAccountSelectorStorageCardCell new];[cell updateWithItem:item];assert(CellCalls==1);
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Unlimited storage"]);
  GSSetUnlimitedStorage(NO);item=[mapper cardItemFromCardData:original];assert(item.sourceData==original&&item.storageState==0);
  assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native regular title"]);
  GSSetUnlimitedStorage(YES);CheckProjection([[mapper cardItemFromCardData:original]sourceData],original);
  // The previous exact-class check rejected Foundation's real KVO subclass.
  GSStorageObserver *observer=[GSStorageObserver new];
  [original addObserver:observer forKeyPath:@"storageState" options:0 context:NULL];
  assert(object_getClass(original)!=OGLAccountMenuStorageCardData.class);
  item=[mapper cardItemFromCardData:original];CheckProjection(item.sourceData,original);
  [original removeObserver:observer forKeyPath:@"storageState"];
  OGLAccountMenuStorageCardData *next=Card();next.usedStorage=1;next.totalStorage=100;
  CheckProjection([[mapper cardItemFromCardData:next]sourceData],next);
  next.usedStorage=2;CheckProjection([[mapper cardItemFromCardData:next]sourceData],next);
  NSObject *other=[NSObject new];assert([mapper cardItemFromCardData:other]==other);assert([mapper cardItemFromCardData:nil]==nil);
  // The superclass converter is not swizzled when a local override is added.
  assert([[GSStorageFixtureMapper cardItemFromCardData:original]sourceData]==original);
  NSDictionary *snapshot=GSUnlimitedStorageSnapshot();
  assert([snapshot[@"implementation"]isEqual:@"native-card-renderer-v3"]&&[snapshot[@"projectedCards"]unsignedLongValue]==5&&[snapshot[@"copyFailures"]unsignedLongValue]==0&&ResourceCalls);
  assert([snapshot[@"renderedStorageState"]integerValue]==2&&[snapshot[@"mappedStorageState"]integerValue]==2&&[snapshot[@"cellUpdates"]unsignedLongValue]==1);
  assert([snapshot[@"cardClasses"]containsObject:@"NSKVONotifying_OGLAccountMenuStorageCardData"]);
  NSSet *keys=[NSSet setWithArray:@[@"implementation",@"available",@"enabled",@"status",@"stringsReady",@"mapperCalls",@"projectedCards",@"copyFailures",@"cellUpdates",@"titleCalls",@"mappedStorageState",@"renderedStorageState",@"cardClasses",@"itemClasses"]];assert([[NSSet setWithArray:snapshot.allKeys]isEqual:keys]);
 }
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 NSLog(@"PASS native card converter, KVO subclass, cached-source restoration, cell observation and ABI guard");
}}
