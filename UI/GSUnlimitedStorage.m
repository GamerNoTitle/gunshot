#import "GSUnlimitedStorage.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>
#include <stdatomic.h>

static NSString *const GSStoragePreference=@"GSShowUnlimitedStorage";
static NSString *const GSAggregatorName=@"_TtC102googlemac_iPhone_Shared_OneGoogle_AccountSelector_Cards_Implementation_OGLAggregatorCardDataSourceImpl31OGLAggregatorCardDataSourceImpl";
static const NSInteger GSNativeUnlimitedState=2;
static BOOL GSStorageInstalled, GSLegacyInstalled, GSAggregateInstalled;
static NSString *GSStorageStatus=@"not-installed";
static id (*GSOriginalStorageData)(id,SEL), (*GSOriginalCards)(id,SEL);
static id (*GSOriginalStorageTitle)(id,SEL,id);
static atomic_ulong GSLegacyCalls, GSAggregateCalls, GSProjectedCards, GSCopyFailures;
static atomic_bool GSStringsReady;

// Every stored property on the audited native presentation model. Copy callbacks
// as well as scalar flags; never archive blocks or change a cached source object.
static const struct { const char *name; const char *type; } GSStorageFields[]={
 {"dataMode","Q"},{"cardActionCallback","@?"},{"title","@"},{"iconType","q"},
 {"storageState","q"},{"usedStorage","d"},{"totalStorage","d"},{"recalculatingStorage","B"},
 {"cardSecondActionCallback","@?"},{"invokeSecondActionForCell","B"},
 {"showActionWithoutUsageThreshold","B"},{"showOrganizationOutOfStorageCard","B"},
 {"backupStoppedReason","@"},{"subtitle","@"},{"manageStorageButtonLabel","@"},
 {"secondActionButtonLabel","@"},{"cardTapActionCallBack","@?"},{"isTrailingPrimaryAction","B"}
};
BOOL GSUnlimitedStorageEnabled(void){
 id value=[NSUserDefaults.standardUserDefaults objectForKey:GSStoragePreference];
 return value==nil?YES:[value boolValue];
}
void GSSetUnlimitedStorage(BOOL enabled){[NSUserDefaults.standardUserDefaults setBool:enabled forKey:GSStoragePreference];}
BOOL GSUnlimitedStorageAvailable(void){return GSStorageInstalled;}
NSDictionary *GSUnlimitedStorageSnapshot(void){
 return @{@"available":@(GSStorageInstalled),@"enabled":@(GSUnlimitedStorageEnabled()),
  @"status":GSStorageStatus,@"legacyHook":@(GSLegacyInstalled),@"aggregateHook":@(GSAggregateInstalled),
  @"stringsReady":@(atomic_load(&GSStringsReady)),@"legacyCalls":@(atomic_load(&GSLegacyCalls)),
  @"aggregateCalls":@(atomic_load(&GSAggregateCalls)),@"projectedCards":@(atomic_load(&GSProjectedCards)),
  @"copyFailures":@(atomic_load(&GSCopyFailures))};
}
static BOOL GSStorageMethod(Class cls,NSString *name,const char *encoding){
 Method method=class_getInstanceMethod(cls,NSSelectorFromString(name));
 return method&&!strcmp(method_getTypeEncoding(method),encoding);
}
static NSString *GSSetter(NSString *name){
 return [NSString stringWithFormat:@"set%@%@:",[[name substringToIndex:1]uppercaseString],[name substringFromIndex:1]];
}
static NSString *GSUnlimitedTitle(void){
 // Native OGLStringResources -> OGLResources.oneGoogleResourceBundle. In this
 // binary 0x81 indexes OneGoogleStorageCardUnlimitedTitle; do not guess a bundle
 // location or require resources to be initialized when the dylib is loaded.
 id resources=((id(*)(id,SEL))objc_msgSend)(NSClassFromString(@"OGLStringResources"),NSSelectorFromString(@"sharedInstance"));
 id title=((id(*)(id,SEL,int))objc_msgSend)(resources,NSSelectorFromString(@"stringForID:"),0x81);
 BOOL valid=[title isKindOfClass:NSString.class]&&[title length]&&![title isEqual:@"OneGoogleStorageCardUnlimitedTitle"];
 atomic_store(&GSStringsReady,valid);return valid?title:nil;
}
static id GSStorageProjection(id original){
 if(!GSUnlimitedStorageEnabled()||object_getClass(original)!=NSClassFromString(@"OGLAccountMenuStorageCardData"))return original;
 NSString *title=GSUnlimitedTitle();if(!title)return original;
 @try {
  id copy=[[NSClassFromString(@"OGLAccountMenuStorageCardData") alloc]init];
  if(!copy)return original;
  for(NSUInteger i=0;i<sizeof(GSStorageFields)/sizeof(GSStorageFields[0]);i++){
   NSString *name=@(GSStorageFields[i].name);SEL get=NSSelectorFromString(name),set=NSSelectorFromString(GSSetter(name));
#define GS_COPY_VALUE(T) ((void(*)(id,SEL,T))objc_msgSend)(copy,set,((T(*)(id,SEL))objc_msgSend)(original,get))
   switch(GSStorageFields[i].type[0]){
    case 'q': GS_COPY_VALUE(NSInteger);break;
    case 'Q': GS_COPY_VALUE(NSUInteger);break;
    case 'd': GS_COPY_VALUE(double);break;
    case 'B': GS_COPY_VALUE(BOOL);break;
    default: GS_COPY_VALUE(id);break;
   }
#undef GS_COPY_VALUE
  }
  ((void(*)(id,SEL,NSInteger))objc_msgSend)(copy,NSSelectorFromString(@"setStorageState:"),GSNativeUnlimitedState);
  ((void(*)(id,SEL,id))objc_msgSend)(copy,NSSelectorFromString(@"setTitle:"),title);
  ((void(*)(id,SEL,id))objc_msgSend)(copy,NSSelectorFromString(@"setSubtitle:"),nil);
  atomic_fetch_add(&GSProjectedCards,1);return copy;
 }@catch(NSException *exception){atomic_fetch_add(&GSCopyFailures,1);return original;}
}
static id GSStorageData(id object,SEL selector){
 atomic_fetch_add(&GSLegacyCalls,1);return GSStorageProjection(GSOriginalStorageData(object,selector));
}
static id GSStorageCards(id object,SEL selector){
 atomic_fetch_add(&GSAggregateCalls,1);id cards=GSOriginalCards(object,selector);
 if(!GSUnlimitedStorageEnabled()||![cards isKindOfClass:NSArray.class])return cards;
 NSMutableArray *result=nil;
 for(NSUInteger i=0;i<[cards count];i++){
  id original=cards[i],projected=GSStorageProjection(original);
  if(projected!=original){if(!result)result=[cards mutableCopy];result[i]=projected;}
 }
 return result?[result copy]:cards;
}
static id GSStorageTitle(id cls,SEL selector,id item){
 // Shared by native layout sizing and rendering in the legacy card cell.
 if(GSUnlimitedStorageEnabled()&&object_getClass(item)==NSClassFromString(@"OGLAccountSelectorStorageCardItem")&&
    ((NSInteger(*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"storageState"))==GSNativeUnlimitedState){
  NSString *title=GSUnlimitedTitle();if(title)return title;
 }
 return GSOriginalStorageTitle(cls,selector,item);
}
static IMP GSStorageReplace(Class cls,SEL selector,IMP replacement){
 Method method=class_getInstanceMethod(cls,selector);IMP original=method_getImplementation(method);
 if(!class_addMethod(cls,selector,replacement,method_getTypeEncoding(method)))method_setImplementation(method,replacement);
 return original;
}
void GSInstallUnlimitedStorage(void){
 if(GSStorageInstalled)return;
 if(![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"]||
    ![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqual:@"7.92.0"]){GSStorageStatus=@"unsupported-host-version";return;}
 Class source=NSClassFromString(@"PHSMyAccountMenuDataSource"),data=NSClassFromString(@"OGLAccountMenuStorageCardData");
 Class aggregate=NSClassFromString(GSAggregatorName),strings=NSClassFromString(@"OGLStringResources");
 Class item=NSClassFromString(@"OGLAccountSelectorStorageCardItem"),cell=NSClassFromString(@"OGLAccountSelectorStorageCardCell");
 GSStorageStatus=@"incompatible-model-abi";
 for(NSUInteger i=0;i<sizeof(GSStorageFields)/sizeof(GSStorageFields[0]);i++){
  NSString *name=@(GSStorageFields[i].name),*type=@(GSStorageFields[i].type);
  NSString *getter=[NSString stringWithFormat:@"%@16@0:8",type];
  NSString *setter=[NSString stringWithFormat:@"v%d@0:8%@16",[type isEqual:@"B"]?20:24,type];
  if(!GSStorageMethod(data,name,getter.UTF8String)||!GSStorageMethod(data,GSSetter(name),setter.UTF8String))return;
 }
 GSStorageStatus=@"incompatible-resources-abi";
 if(!GSStorageMethod(object_getClass(strings),@"sharedInstance","@16@0:8")||!GSStorageMethod(strings,@"stringForID:","@20@0:8i16"))return;
 GSStorageStatus=@"incompatible-card-abi";
 if(!GSStorageMethod(item,@"storageState","q16@0:8")||!GSStorageMethod(object_getClass(cell),@"titleTextWithStorageItem:","@24@0:8@16"))return;
 GSStorageStatus=@"incompatible-source-abi";
 // Both are present in the audited 7.92.0 build; validate before changing any IMP.
 if(!GSStorageMethod(source,@"storageCardData","@16@0:8")||!GSStorageMethod(aggregate,@"accountMenuCardData","@16@0:8"))return;
 GSOriginalStorageData=(void *)GSStorageReplace(source,NSSelectorFromString(@"storageCardData"),(IMP)GSStorageData);
 GSOriginalCards=(void *)GSStorageReplace(aggregate,NSSelectorFromString(@"accountMenuCardData"),(IMP)GSStorageCards);
 GSOriginalStorageTitle=(void *)GSStorageReplace(object_getClass(cell),NSSelectorFromString(@"titleTextWithStorageItem:"),(IMP)GSStorageTitle);
 GSLegacyInstalled=YES;GSAggregateInstalled=YES;GSStorageInstalled=YES;GSStorageStatus=@"installed";
}
