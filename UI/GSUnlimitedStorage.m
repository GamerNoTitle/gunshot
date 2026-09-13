#import "GSUnlimitedStorage.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>
#include <stdatomic.h>

static NSString *const GSStoragePreference=@"GSShowUnlimitedStorage";
static const NSInteger GSNativeUnlimitedState=2;
static BOOL GSStorageInstalled;
static NSString *GSStorageStatus=@"not-installed";
static id (*GSOriginalCardItem)(id,SEL,id), (*GSOriginalStorageTitle)(id,SEL,id);
static void (*GSOriginalCellUpdate)(id,SEL,id);
static atomic_ulong GSMapperCalls, GSProjectedCards, GSCopyFailures, GSCellUpdates, GSTitleCalls;
static atomic_long GSMappedState=-1, GSRenderedState=-1;
static atomic_bool GSStringsReady;
static NSObject *GSStorageLock;
static NSMutableOrderedSet *GSObservedCardClasses, *GSObservedItemClasses;

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
 @synchronized(GSStorageLock){return @{@"implementation":@"native-card-renderer-v3",
  @"available":@(GSStorageInstalled),@"enabled":@(GSUnlimitedStorageEnabled()),@"status":GSStorageStatus,
  @"stringsReady":@(atomic_load(&GSStringsReady)),@"mapperCalls":@(atomic_load(&GSMapperCalls)),
  @"projectedCards":@(atomic_load(&GSProjectedCards)),@"copyFailures":@(atomic_load(&GSCopyFailures)),
  @"cellUpdates":@(atomic_load(&GSCellUpdates)),@"titleCalls":@(atomic_load(&GSTitleCalls)),
  @"mappedStorageState":@(atomic_load(&GSMappedState)),@"renderedStorageState":@(atomic_load(&GSRenderedState)),
  @"cardClasses":GSObservedCardClasses.array?:@[],@"itemClasses":GSObservedItemClasses.array?:@[]};}
}
static void GSStorageObserve(id object,NSMutableOrderedSet *classes){
 if(!object)return;NSString *name=NSStringFromClass(object_getClass(object));
 @synchronized(GSStorageLock){if(classes.count<16)[classes addObject:name];}
}
static BOOL GSStorageMethod(Class cls,NSString *name,const char *encoding){
 Method method=class_getInstanceMethod(cls,NSSelectorFromString(name));
 return method&&!strcmp(method_getTypeEncoding(method),encoding);
}
static NSString *GSSetter(NSString *name){
 return [NSString stringWithFormat:@"set%@%@:",[[name substringToIndex:1]uppercaseString],[name substringFromIndex:1]];
}
static BOOL GSStorageModelCompatible(Class cls){
 for(NSUInteger i=0;i<sizeof(GSStorageFields)/sizeof(GSStorageFields[0]);i++){
  NSString *name=@(GSStorageFields[i].name),*type=@(GSStorageFields[i].type);
  NSString *getter=[NSString stringWithFormat:@"%@16@0:8",type];
  NSString *setter=[NSString stringWithFormat:@"v%d@0:8%@16",[type isEqual:@"B"]?20:24,type];
  if(!GSStorageMethod(cls,name,getter.UTF8String)||!GSStorageMethod(cls,GSSetter(name),setter.UTF8String))return NO;
 }
 return YES;
}
static BOOL GSStorageItem(id item){
 return [item isKindOfClass:NSClassFromString(@"OGLAccountSelectorStorageCardItem")]&&
  GSStorageMethod(object_getClass(item),@"storageState","q16@0:8");
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
 if(!GSUnlimitedStorageEnabled()||![original isKindOfClass:NSClassFromString(@"OGLAccountMenuStorageCardData")])return original;
 if(!GSStorageModelCompatible(object_getClass(original))){atomic_fetch_add(&GSCopyFailures,1);return original;}
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
static id GSStorageCardItem(id cls,SEL selector,id data){
 atomic_fetch_add(&GSMapperCalls,1);GSStorageObserve(data,GSObservedCardClasses);
 // This is the audited presentation boundary used by cardSectionsWithData:,
 // including providers/cached arrays that bypass both previous source hooks.
 id item=GSOriginalCardItem(cls,selector,GSStorageProjection(data));
 GSStorageObserve(item,GSObservedItemClasses);
 if(GSStorageItem(item))atomic_store(&GSMappedState,((NSInteger(*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"storageState")));
 return item;
}
static void GSStorageCellUpdate(id object,SEL selector,id item){
 atomic_fetch_add(&GSCellUpdates,1);
 if(GSStorageItem(item))atomic_store(&GSRenderedState,((NSInteger(*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"storageState")));
 // Observation only: UIKit retains ownership of layout, progress and actions.
 GSOriginalCellUpdate(object,selector,item);
}
static id GSStorageTitle(id cls,SEL selector,id item){
 atomic_fetch_add(&GSTitleCalls,1);
 if(GSUnlimitedStorageEnabled()&&GSStorageItem(item)&&
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
 Class data=NSClassFromString(@"OGLAccountMenuStorageCardData"),strings=NSClassFromString(@"OGLStringResources");
 Class item=NSClassFromString(@"OGLAccountSelectorStorageCardItem"),cell=NSClassFromString(@"OGLAccountSelectorStorageCardCell");
 Class mapper=NSClassFromString(@"OGLGM2AccountSelectorViewModelItemUtils");
 GSStorageStatus=@"incompatible-model-abi";if(!GSStorageModelCompatible(data))return;
 GSStorageStatus=@"incompatible-resources-abi";
 if(!GSStorageMethod(object_getClass(strings),@"sharedInstance","@16@0:8")||!GSStorageMethod(strings,@"stringForID:","@20@0:8i16"))return;
 GSStorageStatus=@"incompatible-card-abi";
 if(!GSStorageMethod(item,@"storageState","q16@0:8")||!GSStorageMethod(object_getClass(cell),@"titleTextWithStorageItem:","@24@0:8@16")||
    !GSStorageMethod(cell,@"updateWithItem:","v24@0:8@16"))return;
 GSStorageStatus=@"incompatible-mapper-abi";
 if(!GSStorageMethod(object_getClass(mapper),@"cardItemFromCardData:","@24@0:8@16"))return;
 GSStorageLock=[NSObject new];GSObservedCardClasses=[NSMutableOrderedSet orderedSet];GSObservedItemClasses=[NSMutableOrderedSet orderedSet];
 GSOriginalCardItem=(void *)GSStorageReplace(object_getClass(mapper),NSSelectorFromString(@"cardItemFromCardData:"),(IMP)GSStorageCardItem);
 GSOriginalStorageTitle=(void *)GSStorageReplace(object_getClass(cell),NSSelectorFromString(@"titleTextWithStorageItem:"),(IMP)GSStorageTitle);
 GSOriginalCellUpdate=(void *)GSStorageReplace(cell,NSSelectorFromString(@"updateWithItem:"),(IMP)GSStorageCellUpdate);
 GSStorageInstalled=YES;GSStorageStatus=@"installed";
}
