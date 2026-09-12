#import "../Shared/GSLocalization.h"
#import "GSBackupRequests.h"
#import "GSNativeRouting.h"
#import "GSNativeAccount.h"
#import "GSExporter.h"
#import "../Shared/IPCProtocol.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Audited 7.92.0 asset request boundary, shared by manual and automatic backup.
// Native success is NEVER fabricated: after Go commits, native fingerprint
// lookup reconciles the real remote item. Native payload fallbacks are blocked.
@interface GSBackupTransfer : NSObject
@property(atomic) BOOL cancelled;
@property(atomic) BOOL cancelGo;
@property(atomic) BOOL reconciling;
@property(atomic,copy) NSString *jobID;
@property(nonatomic,copy) NSString *account;
@property(nonatomic,copy) NSString *localID;
@end
@implementation GSBackupTransfer @end
static char GSTransferKey;
static BOOL GSInstalled;
static NSObject *GSLock;
static NSMutableDictionary *GSCounts;
static NSMutableSet *GSReconciling;
static BOOL GSMethod(id object,NSString *name,const char *encoding){
 Method m=class_getInstanceMethod(object_getClass(object),NSSelectorFromString(name));return m&&!strcmp(method_getTypeEncoding(m),encoding);
}
static id GSGet(id object,NSString *name){return GSMethod(object,name,"@16@0:8")?((id(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name)):nil;}
static void GSCount(NSString *key){@synchronized(GSLock){GSCounts[key]=@([GSCounts[key]unsignedIntegerValue]+1);}}
BOOL GSBackupRequestsAvailable(void){return GSInstalled;}
NSDictionary *GSBackupRequestsSnapshot(void){if(!GSInstalled)return @{@"available":@NO};@synchronized(GSLock){NSMutableDictionary *d=[GSCounts mutableCopy];d[@"available"]=@YES;d[@"enabled"]=GSNativeRoutingEnabled()?@YES:@NO;return d;}}
static void GSFail(id request,NSInteger code){
 NSError *error=[NSError errorWithDomain:@"GoToHP.Backup" code:code userInfo:@{NSLocalizedDescriptionKey:GSL(@"Check the GoToHP queue for details. Native upload has not been used.")}];
 if(GSMethod(request,@"didCompleteWithSuccess:resultantMediaItem:error:","v36@0:8B16@20@28"))
  ((void(*)(id,SEL,BOOL,id,id))objc_msgSend)(request,NSSelectorFromString(@"didCompleteWithSuccess:resultantMediaItem:error:"),NO,nil,error);
 else if(GSMethod(request,@"didCompleteWithError:resultantMediaItem:","v32@0:8@16@24"))
  ((void(*)(id,SEL,id,id))objc_msgSend)(request,NSSelectorFromString(@"didCompleteWithError:resultantMediaItem:"),error,nil);
}
static BOOL GSCanPrepare(NSDictionary *options){
 NSDictionary *runtime=GSEmbeddedRuntimeSnapshot();
 return options&&[runtime[@"conditionsAccepted"]boolValue]&&[runtime[@"foreground"]boolValue]&&[runtime[@"networkOnline"]boolValue]&&![options[@"paused"]boolValue]&&(![options[@"wifiOnly"]boolValue]||[runtime[@"wifi"]boolValue])&&(![options[@"chargingOnly"]boolValue]||[runtime[@"charging"]boolValue]);
}
static void GSStart(id request,SEL selector,IMP original){
 GSBackupTransfer *existing=objc_getAssociatedObject(request,&GSTransferKey);
 if(existing){if(existing.reconciling)((void(*)(id,SEL))original)(request,selector);return;}
 if(!GSNativeRoutingEnabled()){((void(*)(id,SEL))original)(request,selector);return;}
 PHAsset *asset=GSGet(request,@"asset");
 // The audited request ivar is PHAsset, never a compressed GMUUploadAsset.
 if(![asset isKindOfClass:PHAsset.class]){GSCount(@"unsupported");GSFail(request,1);return;}
 BOOL reconciling;@synchronized(GSLock){reconciling=[GSReconciling containsObject:asset.localIdentifier];}
 if(reconciling){((void(*)(id,SEL))original)(request,selector);return;}
 GSBackupTransfer *transfer=[GSBackupTransfer new];transfer.localID=asset.localIdentifier;
 objc_setAssociatedObject(request,&GSTransferKey,transfer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);GSCount(@"intercepted");
 dispatch_async(dispatch_get_main_queue(),^{
  NSDictionary *account=GSNativeAccountSummary();NSString *destination=GSNativeRoutingAccount();
  if(transfer.cancelled)return;
  if(![destination isEqual:account[@"email"]]||!GSNativeAccountMatches(GSGet(GSGet(request,@"credentials"),@"accountID"))){GSCount(@"accountMismatch");GSFail(request,2);return;}
  transfer.account=destination;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   NSError *error=nil;
   NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);
   NSDictionary *options=error?nil:GSRequest(@{@"op":@"options"},&error);
   if(![accounts[@"selected"]isEqual:destination])error=[NSError errorWithDomain:@"GoToHP.Backup" code:2 userInfo:nil];
   NSDate *prepareDeadline=[NSDate dateWithTimeIntervalSinceNow:24*60*60];
   while(!error&&!transfer.cancelled&&!GSCanPrepare(options)&&prepareDeadline.timeIntervalSinceNow>0){
    [NSThread sleepForTimeInterval:1];options=GSRequest(@{@"op":@"options"},&error);
   }
   if(!GSCanPrepare(options))error=[NSError errorWithDomain:@"GoToHP.Backup" code:5 userInfo:nil];
   NSURL *directory=[NSURL fileURLWithPath:[NSTemporaryDirectory()stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
   NSArray *files=nil;
   if(!error&&[NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error])files=GSExportAsset(asset,directory,&error);
   NSString *job=(!transfer.cancelled&&files)?GSImportFiles(files,destination,options[@"quality"]?:@"original",asset.creationDate,&error):nil;
   [NSFileManager.defaultManager removeItemAtURL:directory error:nil];transfer.jobID=job;
   if(job&&transfer.cancelled&&transfer.cancelGo)GSRequest(@{@"op":@"cancel",@"id":job},nil);
   if(job)GSCount(@"queued");
   BOOL completed=NO;NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:24*60*60];
   while(job&&!transfer.cancelled&&deadline.timeIntervalSinceNow>0){@autoreleasepool{
    NSDictionary *state=GSRequest(@{@"op":@"job",@"id":job},&error);
    if(!state)break;
    NSString *phase=state[@"state"];
    if([phase isEqual:@"completed"]){completed=[state[@"mediaKey"]length]>0;break;}
    if([phase isEqual:@"failed"]||[phase isEqual:@"cancelled"])break;
    [NSThread sleepForTimeInterval:1];
   }}
   dispatch_async(dispatch_get_main_queue(),^{
    if(transfer.cancelled)return;
    if(!completed){GSCount(@"failed");GSFail(request,3);return;}
    if(!GSNativeAccountMatches(GSGet(GSGet(request,@"credentials"),@"accountID"))){GSFail(request,2);return;}
    // Let Google query its own server and create the real media model / local
    // backup state. If it attempts a native upload instead, GSGuard blocks it.
    transfer.reconciling=YES;@synchronized(GSLock){[GSReconciling addObject:transfer.localID];}
    GSCount(@"reconciling");((void(*)(id,SEL))original)(request,selector);
   });
  });
 });
}
static void GSReplace(Class c,SEL s,IMP replacement){Method m=class_getInstanceMethod(c,s);if(!class_addMethod(c,s,replacement,method_getTypeEncoding(m)))method_setImplementation(class_getInstanceMethod(c,s),replacement);}
static void GSFinish(id request,BOOL success){
 GSBackupTransfer *t=objc_getAssociatedObject(request,&GSTransferKey);
 if(t.localID)@synchronized(GSLock){[GSReconciling removeObject:t.localID];}
 if(t.reconciling)GSCount(success?@"nativeReconciled":@"reconcileFailed");
}
static void GSBindCompletion(Class c,BOOL live){
 SEL s=NSSelectorFromString(live?@"didCompleteWithError:resultantMediaItem:":@"didCompleteWithSuccess:resultantMediaItem:error:");
 IMP old=method_getImplementation(class_getInstanceMethod(c,s));
 if(live)GSReplace(c,s,imp_implementationWithBlock(^(id request,id error,id result){GSFinish(request,error==nil);((void(*)(id,SEL,id,id))old)(request,s,error,result);}));
 else GSReplace(c,s,imp_implementationWithBlock(^(id request,BOOL success,id result,id error){GSFinish(request,success&&error==nil);((void(*)(id,SEL,BOOL,id,id))old)(request,s,success,result,error);}));
}
static void GSBindStart(Class c){
 SEL s=NSSelectorFromString(@"start");IMP original=method_getImplementation(class_getInstanceMethod(c,s));
 GSReplace(c,s,imp_implementationWithBlock(^(id request){GSStart(request,s,original);}));
 SEL started=NSSelectorFromString(@"didStart");IMP oldStarted=method_getImplementation(class_getInstanceMethod(c,started));
 GSReplace(c,started,imp_implementationWithBlock(^BOOL(id request){GSBackupTransfer *t=objc_getAssociatedObject(request,&GSTransferKey);return t&&!t.reconciling&&!t.cancelled?YES:((BOOL(*)(id,SEL))oldStarted)(request,started);}));
 SEL timeout=NSSelectorFromString(@"shouldTimeout");IMP oldTimeout=method_getImplementation(class_getInstanceMethod(c,timeout));
 GSReplace(c,timeout,imp_implementationWithBlock(^BOOL(id request){GSBackupTransfer *t=objc_getAssociatedObject(request,&GSTransferKey);return t&&!t.reconciling&&!t.cancelled?NO:((BOOL(*)(id,SEL))oldTimeout)(request,timeout);}));
 SEL cancel=NSSelectorFromString(@"cancel");IMP oldCancel=method_getImplementation(class_getInstanceMethod(c,cancel));
 GSReplace(c,cancel,imp_implementationWithBlock(^(id request){
  GSBackupTransfer *t=objc_getAssociatedObject(request,&GSTransferKey);t.cancelGo=[GSEmbeddedRuntimeSnapshot()[@"foreground"]boolValue];t.cancelled=YES;
  if(t.localID)@synchronized(GSLock){[GSReconciling removeObject:t.localID];}
  // Background cancellation belongs to the native scheduler. The durable Go
  // queue resumes on foreground. An explicit foreground cancel also cancels Go.
  if(t.jobID&&t.cancelGo)dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{GSRequest(@{@"op":@"cancel",@"id":t.jobID},nil);});
  ((void(*)(id,SEL))oldCancel)(request,cancel);
 }));
}
static BOOL GSBlockNative(void){BOOL active;@synchronized(GSLock){active=GSReconciling.count>0;}return GSNativeRoutingEnabled()||active;}
static void GSGuard(id request,SEL selector,IMP original){
 if(GSBlockNative()||objc_getAssociatedObject(request,&GSTransferKey)){GSCount(@"nativePayloadBlocked");GSFail(request,4);return;}
 ((void(*)(id,SEL))original)(request,selector);
}
static void GSBindScotty(void){
 Class c=NSClassFromString(@"_TtC84googlemac_iPhone_Shared_Photos_Upload_Request_Scotty_ScottyUploadServiceImpl_ImplLib23ScottyUploadServiceImpl");
 SEL s=NSSelectorFromString(@"uploadWithAsset:shouldAllowCellular:useBackgroundSession:start:progress:onDataReleased:completionHandler:");
 Method m=class_getInstanceMethod(c,s);
 if(m&&!strcmp(method_getTypeEncoding(m),"v64@0:8@\"GMUUploadAsset\"16B24B28@?<v@?B>32@?<v@?d>40@?<v@?>48@?<v@?@\"NSData\"@\"NSError\">56")){
  IMP old=method_getImplementation(m);
  GSReplace(c,s,imp_implementationWithBlock(^(id service,id asset,BOOL cellular,BOOL background,id start,id progress,id released,void(^done)(id,id)){
   if(!GSBlockNative()){((void(*)(id,SEL,id,BOOL,BOOL,id,id,id,id))old)(service,s,asset,cellular,background,start,progress,released,done);return;}
   GSCount(@"nativePayloadBlocked");if(released)((void(^)(void))released)();if(done)done(nil,[NSError errorWithDomain:@"GoToHP.Backup" code:4 userInfo:nil]);
  }));
 }
 SEL stateless=NSSelectorFromString(@"statelessUploadWithAsset:shouldAllowCellular:progress:completionHandler:");m=class_getInstanceMethod(c,stateless);
 if(m&&!strcmp(method_getTypeEncoding(m),"v44@0:8@\"GMUUploadAsset\"16B24@?<v@?d>28@?<v@?@\"NSData\"@\"NSError\">36")){
  IMP old=method_getImplementation(m);
  GSReplace(c,stateless,imp_implementationWithBlock(^(id service,id asset,BOOL cellular,id progress,void(^done)(id,id)){
   if(!GSBlockNative()){((void(*)(id,SEL,id,BOOL,id,id))old)(service,stateless,asset,cellular,progress,done);return;}
   GSCount(@"nativePayloadBlocked");if(done)done(nil,[NSError errorWithDomain:@"GoToHP.Backup" code:4 userInfo:nil]);
  }));
 }
}
void GSInstallBackupRequests(void){
 if(GSInstalled||!GSIsGooglePhotos()||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqual:@"7.92.0"])return;
 Class asset=NSClassFromString(@"GMUAssetUploadRequest"),live=NSClassFromString(@"GMULivePhotoSingleUploadRequest"),base=NSClassFromString(@"GMUUploadRequest");
 for(Class c in @[asset?:NSObject.class,live?:NSObject.class])for(NSArray *entry in @[@[@"start",@"v16@0:8"],@[@"cancel",@"v16@0:8"],@[@"shouldTimeout",@"B16@0:8"],@[@"didStart",@"B16@0:8"],@[@"asset",@"@16@0:8"],@[@"credentials",@"@16@0:8"]]){
  Method m=class_getInstanceMethod(c,NSSelectorFromString(entry[0]));if(!m||strcmp(method_getTypeEncoding(m),[entry[1]UTF8String]))return;
 }
 Method fetch=class_getInstanceMethod(base,NSSelectorFromString(@"startFetcher"));if(!fetch||strcmp(method_getTypeEncoding(fetch),"v16@0:8"))return;
 Method ac=class_getInstanceMethod(asset,NSSelectorFromString(@"didCompleteWithSuccess:resultantMediaItem:error:")),lc=class_getInstanceMethod(live,NSSelectorFromString(@"didCompleteWithError:resultantMediaItem:"));
 if(!ac||!lc||strcmp(method_getTypeEncoding(ac),"v36@0:8B16@20@28")||strcmp(method_getTypeEncoding(lc),"v32@0:8@16@24"))return;
 GSLock=[NSObject new];GSCounts=[NSMutableDictionary dictionary];GSReconciling=[NSMutableSet set];
 GSBindStart(asset);GSBindStart(live);GSBindCompletion(asset,NO);GSBindCompletion(live,YES);
 SEL s=NSSelectorFromString(@"startFetcher");IMP original=method_getImplementation(fetch);GSReplace(base,s,imp_implementationWithBlock(^(id request){GSGuard(request,s,original);}));
 Class media=NSClassFromString(@"GMUUploadMediaRequest");SEL cnde=NSSelectorFromString(@"startCNDEUpload");Method cm=class_getInstanceMethod(media,cnde);
 if(cm&&!strcmp(method_getTypeEncoding(cm),"v16@0:8")){IMP old=method_getImplementation(cm);GSReplace(media,cnde,imp_implementationWithBlock(^(id request){GSGuard(request,cnde,old);}));}
 GSBindScotty();GSInstalled=YES;
}
