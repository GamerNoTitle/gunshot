#import "GSPhotosIntegration.h"
#import "GSNativeAccount.h"
#import "GSNativeRouting.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface PHSOneUpInfoPanelBackupStatusData : NSObject
- (instancetype)initWithBackupStatus:(NSString *)status backupStatusSubtitle:(NSString *)subtitle learnMoreLink:(NSString *)link;
@end

// Exact 7.92.0 metadata. Never set backup flags or edit the native database.
static NSObject *GSLock;
static NSMapTable *GSSynchronizers;
static NSMutableDictionary *GSCounts;
static BOOL GSInstalled, GSQualityAvailable, GSSyncAvailable, GSPending, GSScheduled;
static BOOL GSMethod(id object,NSString *name,const char *encoding){
 Method m=class_getInstanceMethod(object_getClass(object),NSSelectorFromString(name));
 return m&&!strcmp(method_getTypeEncoding(m),encoding);
}
static id GSGet(id object,NSString *name){return GSMethod(object,name,"@16@0:8")?((id(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name)):nil;}
static void GSCount(NSString *key){@synchronized(GSLock){GSCounts[key]=@([GSCounts[key]unsignedIntegerValue]+1);}}
NSDictionary *GSPhotosIntegrationSnapshot(void){
 if(!GSInstalled)return @{@"qualityAvailable":@NO,@"syncAvailable":@NO};
 @synchronized(GSLock){NSMutableDictionary *d=[GSCounts mutableCopy];d[@"qualityAvailable"]=GSQualityAvailable?@YES:@NO;d[@"syncAvailable"]=GSSyncAvailable?@YES:@NO;return d;}
}
static void GSFlushRefresh(void){
 if(!GSPending||GSScheduled)return;GSScheduled=YES;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  GSScheduled=NO;if(!GSPending)return;
  id target=nil;
  @synchronized(GSLock){for(id account in GSSynchronizers.keyEnumerator)if(GSNativeAccountMatches(account)){target=[GSSynchronizers objectForKey:account];break;}}
  if(!target){GSCount(@"syncWaitingForAccount");return;}
  GSPending=NO;GSCount(@"syncRequested");
  // fetchData -> fetchWithType:0 enters the app's existing sync queue and
  // publishes real server-store changes to its grid and details subscribers.
  ((void(*)(id,SEL))objc_msgSend)(target,NSSelectorFromString(@"fetchData"));
 });
}
void GSRefreshNativeLibrary(void){
 if(!GSSyncAvailable)return;
 dispatch_async(dispatch_get_main_queue(),^{GSPending=YES;GSFlushRefresh();});
}
static void GSCaptureSynchronizer(id object){
 id account=GSGet(object,@"accountID");if(!account)return;
 @synchronized(GSLock){[GSSynchronizers setObject:object forKey:account];}
 dispatch_async(dispatch_get_main_queue(),^{GSFlushRefresh();});
}
static id GSBackupStatus(id controller,SEL selector,IMP original){
 id status=((id(*)(id,SEL))original)(controller,selector);
 if(!status||!GSNativeRoutingEnabled()||!GSMethod(controller,@"isBackedUp","B16@0:8")||!((BOOL(*)(id,SEL))objc_msgSend)(controller,NSSelectorFromString(@"isBackedUp")))return status;
 id photo=GSGet(GSGet(controller,@"extendedPhoto"),@"serverPhoto");
 if(![photo isKindOfClass:NSClassFromString(@"PHSServerPhoto")]||!GSMethod(photo,@"hasOriginalBytes","C16@0:8")||!GSMethod(photo,@"storagePolicy","C16@0:8")||!GSMethod(photo,@"isPartialBackup","B16@0:8"))return status;
 unsigned char originals=((unsigned char(*)(id,SEL))objc_msgSend)(photo,NSSelectorFromString(@"hasOriginalBytes"));
 // Enum descriptor: Unknown=0, Yes=1, No=2, Maybe=3. Maybe is not Yes.
 GSCount(originals==1?@"serverOriginal":originals==2?@"serverNotOriginal":@"serverOriginalUnknown");
 if(originals!=1||((BOOL(*)(id,SEL))objc_msgSend)(photo,NSSelectorFromString(@"isPartialBackup")))return status;
 unsigned char policy=((unsigned char(*)(id,SEL))objc_msgSend)(photo,NSSelectorFromString(@"storagePolicy"));
 if(policy!=1)return status; // Only the Standard / Storage Saver label mismatch.
 NSString *backup=GSGet(status,@"backupStatus");if(![backup isKindOfClass:NSString.class])return status;
 id replacement=[(PHSOneUpInfoPanelBackupStatusData *)[NSClassFromString(@"PHSOneUpInfoPanelBackupStatusData") alloc] initWithBackupStatus:backup backupStatusSubtitle:@"オリジナル画質（原本データあり）" learnMoreLink:@"https://support.google.com/photos/answer/6220791"];
 if(replacement){GSCount(@"qualityLabelCorrected");return replacement;}
 return status;
}
void GSInstallPhotosIntegration(void){
 if(GSInstalled||!GSIsGooglePhotos()||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqual:@"7.92.0"])return;
 GSLock=[NSObject new];GSCounts=[NSMutableDictionary dictionary];GSSynchronizers=[NSMapTable strongToWeakObjectsMapTable];GSInstalled=YES;
 Class sync=NSClassFromString(@"PHSUserItemsSynchronizer");
 Method fetch=class_getInstanceMethod(sync,NSSelectorFromString(@"fetchData"));
 Method account=class_getInstanceMethod(sync,NSSelectorFromString(@"accountID"));
 if(fetch&&account&&!strcmp(method_getTypeEncoding(fetch),"v16@0:8")&&!strcmp(method_getTypeEncoding(account),"@16@0:8")){
  for(NSString *name in @[@"fetchData",@"fetchDataSoft"]){SEL s=NSSelectorFromString(name);Method m=class_getInstanceMethod(sync,s);if(!m||strcmp(method_getTypeEncoding(m),"v16@0:8"))continue;
   IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^(id object){GSCaptureSynchronizer(object);((void(*)(id,SEL))old)(object,s);}));
  }
  GSSyncAvailable=YES;
 }
 Class details=NSClassFromString(@"PHSOneUpInfoPanelDetailsViewController"),model=NSClassFromString(@"PHSOneUpInfoPanelBackupStatusData");
 SEL s=NSSelectorFromString(@"getBackupStatusModelData");Method m=class_getInstanceMethod(details,s),init=class_getInstanceMethod(model,NSSelectorFromString(@"initWithBackupStatus:backupStatusSubtitle:learnMoreLink:"));
 if(m&&init&&!strcmp(method_getTypeEncoding(m),"@16@0:8")&&!strcmp(method_getTypeEncoding(init),"@40@0:8@16@24@32")){
  IMP old=method_getImplementation(m);method_setImplementation(m,imp_implementationWithBlock(^id(id controller){return GSBackupStatus(controller,s,old);}));GSQualityAvailable=YES;
 }
}
