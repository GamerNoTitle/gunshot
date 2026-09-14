#ifdef GS_TEST_LEGACY
#define GS_ERROR_LABEL errorCode
#define GS_ERROR_TYPE NSInteger
#define GS_NO_ERROR 0
#define GS_FAILURE 73
#else
#define GS_ERROR_LABEL error
#define GS_ERROR_TYPE id
#define GS_NO_ERROR nil
#define GS_FAILURE error
#endif
#import "host_profile.h"
#import "../UI/GSBackupRequests.h"
#import "../UI/GSNativeRouting.h"
#import "native_account_fixture.h"
#import "../Shared/IPCProtocol.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <assert.h>
#include <stdatomic.h>
// Include the adapter so this fixture can shorten only its timer intervals.
#import "../UI/GSBackupRequests.m"
static BOOL remoteMatch=YES;
static atomic_ulong queued,conditionReads,cancelRequests;
static NSUInteger nativeStarts,nativePayload,successes,failures;
static NSUInteger nativeLookups,nativePreparations;
static atomic_bool foreground=YES,online=YES,wifi=YES,charging=YES,paused=NO,holdJob=NO,failJob=NO,switchDuringExport=NO;
static PHSAccount *primaryAccount,*otherAccount;
@implementation PHAsset @end
@interface GSFixtureBundle : NSBundle @end
@implementation GSFixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?@"GooglePhotos":GSFixtureVersion;}
@end
static id Bundle(id self,SEL s){return [GSFixtureBundle new];}
BOOL GSUploadHostForeground(void){return atomic_load(&foreground);}
NSDictionary *GSEmbeddedRuntimeSnapshot(void){conditionReads++;return @{@"foreground":@(atomic_load(&foreground)),@"conditionsAccepted":@YES,@"networkOnline":@(atomic_load(&online)),@"wifi":@(atomic_load(&wifi)),@"charging":@(atomic_load(&charging))};}
NSDictionary *GSRequest(NSDictionary *request,NSError **error){
 assert(!NSThread.isMainThread);
 if([request[@"op"]isEqual:@"accounts"])return @{@"selected":@"test@example.com"};
 if([request[@"op"]isEqual:@"options"])return @{@"quality":@"original",@"wifiOnly":@YES,@"chargingOnly":@YES,@"paused":@(atomic_load(&paused))};
 if([request[@"op"]isEqual:@"upload_summary"]){conditionReads++;return @{@"conditions":@{@"online":@(atomic_load(&online)),@"wifi":@(atomic_load(&wifi)),@"charging":@(atomic_load(&charging)),@"paused":@(atomic_load(&paused))}};}
 if([request[@"op"]isEqual:@"job"])return atomic_load(&holdJob)?@{@"state":@"pending"}:atomic_load(&failJob)?@{@"state":@"failed"}:@{@"state":@"completed",@"mediaKey":@"real-server-key"};
 if([request[@"op"]isEqual:@"cancel"])cancelRequests++;
 return @{};
}
NSArray *GSExportAsset(PHAsset *asset,NSURL *directory,NSError **error){assert(!NSThread.isMainThread);if(atomic_load(&switchDuringExport))dispatch_sync(dispatch_get_main_queue(),^{GSFixtureSelectAccount(otherAccount);});return @[[directory URLByAppendingPathComponent:@"original.heic"]];}
NSString *GSImportFiles(NSArray *files,NSString *account,NSString *quality,NSDate *date,NSError **error){assert([quality isEqual:@"original"]);@synchronized(PHAsset.class){queued++;}return @"job";}
@interface Credentials : NSObject
@property(nonatomic,strong) id accountID;
@end
@implementation Credentials @end
@interface GMUUploadRequest : NSObject
@property(nonatomic,strong) Credentials *credentials;
- (void)startFetcher;
- (_Bool)didStart;
- (void)didCompleteWithSuccess:(_Bool)success resultantMediaItem:(id)item GS_ERROR_LABEL:(GS_ERROR_TYPE)error;
@end
@implementation GMUUploadRequest
- (void)startFetcher{nativePayload++;}
- (_Bool)didStart{return NO;}
- (void)didCompleteWithSuccess:(_Bool)success resultantMediaItem:(id)item GS_ERROR_LABEL:(GS_ERROR_TYPE)error{if(success&&!error)successes++;else failures++;}
@end
@interface GMUAssetUploadRequest : GMUUploadRequest
@property(nonatomic,strong) PHAsset *asset;
@property(nonatomic) BOOL fingerprintLookup,silentLookup;
@property(nonatomic) NSUInteger missesRemaining;
@property(nonatomic,strong) id lastFingerprint;
- (void)start;
- (_Bool)shouldTimeout;
- (void)cancel;
- (void)existenceCheckDidFailWithFingerprint:(id)fingerprint;
- (void)lookup:(id)fingerprint;
@end
@implementation GMUAssetUploadRequest
- (void)start{nativeStarts++;if(self.fingerprintLookup)[self lookup:[NSObject new]];else if(remoteMatch)[self didCompleteWithSuccess:YES resultantMediaItem:nil GS_ERROR_LABEL:GS_NO_ERROR];else[self startFetcher];}
- (_Bool)shouldTimeout{return self.asset.mediaType!=PHAssetMediaTypeVideo;}
- (void)cancel{}
- (void)lookup:(id)fingerprint{
 nativeLookups++;if(self.lastFingerprint)assert(self.lastFingerprint==fingerprint);self.lastFingerprint=fingerprint;
 if(self.silentLookup)return;
 if(self.missesRemaining){self.missesRemaining--;[self existenceCheckDidFailWithFingerprint:fingerprint];}
 else [self didCompleteWithSuccess:YES resultantMediaItem:nil GS_ERROR_LABEL:GS_NO_ERROR];
}
#ifdef GS_TEST_LEGACY
- (void)fingerprintDidComplete:(id)fingerprint{[self lookup:fingerprint];}
#else
- (void)fingerprintDidComplete:(id)fingerprint error:(id)error{assert(!error);[self lookup:fingerprint];}
#endif
- (void)existenceCheckDidFailWithFingerprint:(id)fingerprint{nativePreparations++;[self startFetcher];}
@end
// A separate class as in the real app, not a subclass of GMUAssetUploadRequest.
@interface GMULivePhotoSingleUploadRequest : NSObject
@property(nonatomic,strong) Credentials *credentials;
- (_Bool)didStart;
@property(nonatomic,strong) PHAsset *asset;
- (void)start;
- (_Bool)shouldTimeout;
- (void)cancel;
- (void)didCompleteWithError:(id)error resultantMediaItem:(id)item;
@end
@implementation GMULivePhotoSingleUploadRequest
- (_Bool)didStart{return NO;}
- (void)start{if([self didStart])return;nativeStarts++;[self didCompleteWithError:nil resultantMediaItem:@"live-server-item"];}
- (_Bool)shouldTimeout{return YES;}
- (void)cancel{}
- (void)didCompleteWithError:(id)error resultantMediaItem:(id)item{if(item&&!error)successes++;else failures++;}
@end
static id Request(Class c,id account){id r=[c new];PHAsset *asset=[PHAsset new];asset.localIdentifier=NSUUID.UUID.UUIDString;[r setAsset:asset];Credentials *cred=[Credentials new];cred.accountID=account;[r setCredentials:cred];return r;}
@interface PHSLocalAsset : NSObject
@property(nonatomic,strong) PHAsset *phAsset;
@property(nonatomic) _Bool isLocked;
@end
@implementation PHSLocalAsset @end
static id lastManualRequest;
@interface PHSBackupActionBehaviorImpl : NSObject
- (void)backupLocalAssets:(id)assets;
@end
@implementation PHSBackupActionBehaviorImpl
- (void)backupLocalAssets:(id)assets{lastManualRequest=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[lastManualRequest start];}
@end
@interface PHSActionsGridModel : PHSBackupActionBehaviorImpl @end
@implementation PHSActionsGridModel
- (void)backupLocalAssets:(id)assets{[super backupLocalAssets:assets];}
@end
void GSPresentRoutedAssets(NSArray *assets,NSString *account){assert(!"manual action bypassed native completion");}
static void Await(BOOL(^done)(void)){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!done()&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];assert(done());}
static void Drain(NSUInteger expected){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(successes+failures<expected&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];assert(successes+failures==expected);}
static void Scotty(id object,SEL selector,id asset,BOOL cellular,BOOL background,id start,id progress,void(^released)(void),void(^done)(id,id)){nativePayload++;if(released)released();if(done)done(@"native-result",nil);}
static void Stateless(id object,SEL selector,id asset,BOOL cellular,id progress,void(^done)(id,id)){nativePayload++;if(done)done(@"native-result",nil);}
static GMUAssetUploadRequest *Video(NSUInteger misses,BOOL silent){
 GMUAssetUploadRequest *r=Request(GMUAssetUploadRequest.class,primaryAccount.accountID);
 r.asset.mediaType=PHAssetMediaTypeVideo;r.fingerprintLookup=YES;r.missesRemaining=misses;r.silentLookup=silent;return r;
}
static void Reconciliation(void){
 GSReconcileDelay=0.01;GSReconcileTimeout=1;
 NSUInteger before=queued,finished=successes+failures,lookups=nativeLookups,ok=successes;
 GMUAssetUploadRequest *video=Video(2,NO);[video start];Drain(finished+1);
 assert(queued==before+1&&nativeLookups==lookups+3&&successes==ok+1&&nativePreparations==0&&nativePayload==0);
 // All-negative server results fail once, without a second export or payload.
 before=queued;finished=successes+failures;lookups=nativeLookups;
 video=Video(100,NO);[video start];Drain(finished+1);
 assert(queued==before+1&&nativeLookups==lookups+1+GSReconcileRetryLimit&&successes==ok+1&&nativePreparations==0);
 // The native video API may never time out. A late completion must not deliver
 // a second result after our deadline has already released the request.
 GSReconcileTimeout=0.1;finished=successes+failures;
 video=Video(0,YES);[video start];Drain(finished+1);assert(![video shouldTimeout]);
 [video didCompleteWithSuccess:YES resultantMediaItem:nil GS_ERROR_LABEL:GS_NO_ERROR];
 [video existenceCheckDidFailWithFingerprint:video.lastFingerprint];
 [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
 assert(successes+failures==finished+1&&GSReconciling.count==0);
 GSReconcileTimeout=1;GSReconcileDelay=0.05;
 // Cancellation, disabling routing and account changes invalidate a queued retry.
 for(NSUInteger mode=0;mode<3;mode++){
  finished=successes+failures;lookups=nativeLookups;video=Video(2,NO);[video start];
  Await(^BOOL{return [objc_getAssociatedObject(video,&GSTransferKey) retryPending];});
  if(mode==0)[video cancel];else if(mode==1)GSSetNativeRouting(NO,nil);else GSFixtureSelectAccount(otherAccount);
  if(mode==0){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];assert(successes+failures==finished);}
  else Drain(finished+1);
  assert(nativeLookups==lookups+1&&GSReconciling.count==0);
  GSSetNativeRouting(YES,@"test@example.com");GSFixtureSelectAccount(primaryAccount);
 }
 // Two requests for the same asset each own their reconciliation guard.
 finished=successes+failures;
 GMUAssetUploadRequest *first=Video(0,YES),*second=Video(0,YES);
 second.asset.localIdentifier=first.asset.localIdentifier;
 holdJob=YES;before=queued;[first start];[second start];Await(^BOOL{return queued==before+2;});holdJob=NO;
 Await(^BOOL{return [GSReconciling countForObject:first.asset.localIdentifier]==2;});
 GSSetNativeRouting(NO,nil);[first cancel];assert(GSBlockNative());
 [second didCompleteWithSuccess:YES resultantMediaItem:nil GS_ERROR_LABEL:GS_NO_ERROR];
 assert(successes+failures==finished+1&&!GSBlockNative());
 // Disabled routing preserves the native miss path.
 before=nativePreparations;NSUInteger payload=nativePayload;
 video=Video(1,NO);[video start];assert(nativePreparations==before+1&&nativePayload==payload+1);
 GSSetNativeRouting(YES,@"test@example.com");
 NSDictionary *d=GSBackupRequestsSnapshot();
 assert([d[@"reconcileExhausted"]unsignedIntegerValue]==1&&[d[@"reconcileTimedOut"]unsignedIntegerValue]==1);
 NSLog(@"PASS video visibility retries, retry exhaustion, missing/late completion, cancellation, account/toggle changes and overlapping reconciliation");
}
int main(void){@autoreleasepool{
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)Bundle);
 primaryAccount=GSFixtureMakeAccount(@"fixture-user-A",@"test@example.com");
 otherAccount=GSFixtureMakeAccount(@"fixture-user-B",@"other@example.com");GSFixtureSelectAccount(primaryAccount);
 assert([GSNativeAccountSummary()[@"identifier"]isEqual:@"fixture-user-A"]);
 assert(GSNativeAccountMatches(primaryAccount.accountID));
 assert(!GSNativeAccountMatches(@"fixture-user-A")); // A native ID is never the SSO string.
 assert(GSNativeIdentityMatches(@"fixture-user-A"));
 assert(!GSNativeIdentityMatches(@"fixture-user-B")&&!GSNativeIdentityMatches(nil)&&!GSNativeIdentityMatches(@""));
 assert(!GSNativeIdentityMatches((NSString *)primaryAccount.accountID));


#ifndef GS_TEST_LEGACY
 Class sc=objc_allocateClassPair(NSObject.class,"_TtC84googlemac_iPhone_Shared_Photos_Upload_Request_Scotty_ScottyUploadServiceImpl_ImplLib23ScottyUploadServiceImpl",0);
 SEL upload=NSSelectorFromString(@"uploadWithAsset:shouldAllowCellular:useBackgroundSession:start:progress:onDataReleased:completionHandler:");
 SEL stateless=NSSelectorFromString(@"statelessUploadWithAsset:shouldAllowCellular:progress:completionHandler:");
 class_addMethod(sc,upload,(IMP)Scotty,"v64@0:8@\"GMUUploadAsset\"16B24B28@?<v@?B>32@?<v@?d>40@?<v@?>48@?<v@?@\"NSData\"@\"NSError\">56");
 class_addMethod(sc,stateless,(IMP)Stateless,"v44@0:8@\"GMUUploadAsset\"16B24@?<v@?d>28@?<v@?@\"NSData\"@\"NSError\">36");objc_registerClassPair(sc);
#endif

 GSInstallNativeRouting();assert(GSBackupRequestsAvailable()&&GSNativeRoutingAvailable());GSSetNativeRouting(NO,nil);
 id plain=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[plain start];assert(nativeStarts==1&&queued==0);
 GSSetNativeRouting(YES,@"test@example.com");[[PHSBackupActionBehaviorImpl new]backupLocalAssets:@[[PHAsset new]]];id manual=lastManualRequest;[manual start];assert([manual didStart]&&![manual shouldTimeout]);assert(nativeStarts==1);Drain(2);assert(queued==1&&nativeStarts==2&&nativePayload==0);
 // The automatic scheduler uses this same asset request, with no UI action.
 id automatic=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[automatic start];Drain(3);assert(queued==2&&nativePayload==0);
 id wrong=Request(GMUAssetUploadRequest.class,otherAccount.accountID);[wrong start];Drain(4);assert(queued==2&&failures==1);
 remoteMatch=NO;id missing=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[missing start];Drain(5);assert(queued==3&&nativePayload==0&&failures==2);
 id live=Request(GMULivePhotoSingleUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[live start];Drain(6);assert(queued==4&&successes==4);
 id cancel=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[cancel start];[cancel cancel];[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];assert(queued==4);
#ifndef GS_TEST_LEGACY
 __block NSUInteger released=0,denied=0;
 ((void(*)(id,SEL,id,BOOL,BOOL,id,id,id,id))objc_msgSend)([sc new],upload,nil,NO,YES,nil,nil,^{released++;},^(id data,id error){assert(!data&&error);denied++;});
 ((void(*)(id,SEL,id,BOOL,id,id))objc_msgSend)([sc new],stateless,nil,NO,nil,^(id data,id error){assert(!data&&error);denied++;});
 assert(released==1&&denied==2&&nativePayload==0);
 NSDictionary *d=GSBackupRequestsSnapshot();assert([d[@"nativeReconciled"]integerValue]==3&&[d[@"nativePayloadBlocked"]integerValue]==3);
#else
 NSDictionary *d=GSBackupRequestsSnapshot();assert([d[@"nativeReconciled"]integerValue]==3&&[d[@"nativePayloadBlocked"]integerValue]==1);
#endif
 remoteMatch=YES;[[PHSActionsGridModel new]backupLocalAssets:@[[PHAsset new]]];Drain(7);assert(queued==5&&successes==5&&nativePayload==0);
 // The native scheduler must wait for each configured condition, then hand off
 // without opening settings, spending retries, or starting native payloads.
 atomic_bool *conditions[]={&online,&wifi,&charging,&paused};
 for(NSUInteger i=0;i<4;i++){
  NSUInteger before=queued,reads=conditionReads,finished=successes+failures;
  atomic_store(conditions[i],i==3?YES:NO);
  id waiting=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[waiting start];
  Await(^BOOL{return conditionReads>reads;});assert(queued==before);
  atomic_store(conditions[i],i==3?NO:YES);Drain(finished+1);assert(queued==before+1&&nativePayload==0);
 }
 // No native success until Go reports a committed item. Daemon jobs survive
 // the native scheduler cancelling its request as the app backgrounds.
 holdJob=YES;NSUInteger before=queued,finished=successes+failures,starts=nativeStarts;
 id background=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[background start];Await(^BOOL{return queued==before+1;});
 assert(successes+failures==finished&&nativeStarts==starts);foreground=NO;[background cancel];
 [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];assert(cancelRequests==0);
 foreground=YES;id cancelled=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[cancelled start];Await(^BOOL{return queued==before+2;});[cancelled cancel];Await(^BOOL{return cancelRequests==1;});holdJob=NO;
 failJob=YES;id failed=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[failed start];Drain(finished+1);assert(nativeStarts==starts&&nativePayload==0);failJob=NO;
 before=queued;finished=successes+failures;switchDuringExport=YES;
 id switched=Request(GMUAssetUploadRequest.class,[[GIPGaiaAccountID alloc]initWithGaiaID:@"fixture-user-A"]);[switched start];Drain(finished+1);assert(queued==before&&nativeStarts==starts);switchDuringExport=NO;GSFixtureSelectAccount(primaryAccount);
 // A raw SSO string with the right value is still not native credentials.
 before=queued;finished=successes+failures;
 id stringCredential=Request(GMUAssetUploadRequest.class,@"fixture-user-A");
 [stringCredential start];Drain(finished+1);assert(queued==before&&nativeStarts==starts);
 // Signing out while preserving the account object also blocks transfer.
 ((GSFixtureIdentity *)primaryAccount->_ssoIdentity).hasValidAuth=NO;finished=successes+failures;
 assert(!GSNativeIdentityMatches(@"fixture-user-A"));
 id invalidAuth=Request(GMUAssetUploadRequest.class,primaryAccount.accountID);
 [invalidAuth start];Drain(finished+1);assert(queued==before&&nativeStarts==starts);
 ((GSFixtureIdentity *)primaryAccount->_ssoIdentity).hasValidAuth=YES;
 assert(GSNativeIdentityMatches(@"fixture-user-A"));
 Reconciliation();
 NSLog(@"PASS native manual UI through Go and native completion, automatic request handoff, original resources, account binding, duplicate start, cancellation and native fallback blocking");
 return 0;
}}
