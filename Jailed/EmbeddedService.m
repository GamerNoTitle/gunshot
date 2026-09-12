#import "../Shared/IPCProtocol.h"
#import <UIKit/UIKit.h>
#import <Network/Network.h>
#import "libgotohp.h"
#import "../UI/GSNativeAccount.h"
#import "../UI/GSPhotosIntegration.h"

// No external IPC in the jailed host. SSO can wait on main, so runtime snapshots
// must never wait on the core queue (including when exporting diagnostics).
static dispatch_queue_t GSCoreQueue;
static BOOL GSReady;
static nw_path_monitor_t GSMonitor;
static dispatch_source_t GSCompletionMonitor;
static NSLock *GSStateLock;
static NSMutableDictionary *GSState;
static void GSStateInitialize(void) {
 static dispatch_once_t once;dispatch_once(&once,^{
  GSStateLock=[NSLock new];
  GSState=[@{@"coreReady":@NO,@"conditionsAccepted":@NO,@"foreground":@NO,@"path":@"unknown",@"networkOnline":@NO,@"wifi":@NO,@"charging":@NO,@"authorization":@"not_checked"} mutableCopy];
 });
}
static void GSRecord(NSDictionary *values) {
 GSStateInitialize();[GSStateLock lock];[GSState addEntriesFromDictionary:values];[GSStateLock unlock];
}
NSDictionary *GSEmbeddedRuntimeSnapshot(void) {
 GSStateInitialize();[GSStateLock lock];NSDictionary *snapshot=[GSState copy];[GSStateLock unlock];return snapshot;
}
static NSDictionary *GSCall(NSDictionary *request,const char *role) {
 NSData *data=[NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
 if(!data||data.length>GS_MAX_JSON)return nil;
 NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 char *raw=GunshotRequest((char *)json.UTF8String,(char *)role);
 if(!raw)return nil;
 NSData *reply=[NSData dataWithBytes:raw length:strlen(raw)];GunshotFree(raw);
 id parsed=[NSJSONSerialization JSONObjectWithData:reply options:0 error:nil];
 if(![parsed isKindOfClass:NSDictionary.class]||![parsed[@"ok"]boolValue])return nil;
 return parsed[@"data"]==NSNull.null?@{}:parsed[@"data"];
}
static void GSConditions(void) {
 NSDictionary *state=GSEmbeddedRuntimeSnapshot();
 if(!GSReady)return;
 // ObjC relational/logical expressions have type int: @(a && b) becomes JSON
 // 1/0, which Go correctly rejects for a bool field. Always box real booleans.
 NSDictionary *result=GSCall(@{@"op":@"conditions",@"online":([state[@"foreground"]boolValue]&&[state[@"networkOnline"]boolValue])?@YES:@NO,@"wifi":[state[@"wifi"]boolValue]?@YES:@NO,@"charging":[state[@"charging"]boolValue]?@YES:@NO},"daemon");
 GSRecord(@{@"conditionsAccepted":result?@YES:@NO});
}
static void GSObserveCompletions(void) {
 static NSNumber *lastRevision;
 NSDictionary *state=GSEmbeddedRuntimeSnapshot();
 if(!GSReady||![state[@"foreground"]boolValue])return;
 NSDictionary *summary=GSCall(@{@"op":@"upload_summary"},"settings");if(!summary)return;
 GSRecord(@{@"uploadSummary":summary});
 if(![state[@"networkOnline"]boolValue])return;
 NSNumber *revision=summary[@"completionRevision"];
 if(revision&&![revision isEqual:lastRevision]){lastRevision=revision;GSRefreshNativeLibrary();}
}
static void GSSampleApplication(void) {
 // Scene lifecycle matters for scene-based hosts and container guests. Inactive
 // foreground scenes still count, e.g. while a system sheet is presented.
 BOOL foreground=UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground;
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
  if(scene.activationState==UISceneActivationStateForegroundActive||scene.activationState==UISceneActivationStateForegroundInactive){foreground=YES;break;}
 UIDeviceBatteryState state=UIDevice.currentDevice.batteryState;
 GSRecord(@{@"foreground":@(foreground),@"charging":(state==UIDeviceBatteryStateCharging||state==UIDeviceBatteryStateFull)?@YES:@NO});
 dispatch_async(GSCoreQueue,^{GSConditions();});
}
static void GSStart(void) {
 static dispatch_once_t once;dispatch_once(&once,^{
 GSStateInitialize();GSCoreQueue=dispatch_queue_create("dev.tqmane.gunshot.embedded",DISPATCH_QUEUE_SERIAL);
 NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *root=[support URLByAppendingPathComponent:@"GoToHP" isDirectory:YES];
 dispatch_async(GSCoreQueue,^{
 if(!root||![NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700,NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil])return;
 [root setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
 GunshotSetHostBearerProvider((uintptr_t)&GSNativeBearer);
 GSReady=GunshotInitialize((char *)root.path.UTF8String)==0;
 GSRecord(@{@"coreReady":@(GSReady)});GSConditions();
 // Observe durable commits even when the GoToHP panel has been dismissed.
 // Only request the host's read-only delta sync; never manufacture a success.
 GSCompletionMonitor=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,GSCoreQueue);
 dispatch_source_set_timer(GSCompletionMonitor,dispatch_time(DISPATCH_TIME_NOW,0),3*NSEC_PER_SEC,NSEC_PER_SEC/2);
 dispatch_source_set_event_handler(GSCompletionMonitor,^{GSObserveCompletions();});dispatch_resume(GSCompletionMonitor);
 });
 dispatch_async(dispatch_get_main_queue(),^{
 UIDevice.currentDevice.batteryMonitoringEnabled=YES;
 for(NSString *name in @[UIApplicationDidBecomeActiveNotification,UIApplicationDidEnterBackgroundNotification,UIApplicationWillEnterForegroundNotification,UISceneDidActivateNotification,UISceneWillDeactivateNotification,UISceneDidEnterBackgroundNotification,UISceneWillEnterForegroundNotification,UIDeviceBatteryStateDidChangeNotification])
  [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){GSSampleApplication();}];
 GSSampleApplication();
 });
 GSMonitor=nw_path_monitor_create();
 nw_path_monitor_set_update_handler(GSMonitor,^(nw_path_t path){
  nw_path_status_t status=nw_path_get_status(path);
  GSRecord(@{@"path":status==nw_path_status_satisfied?@"satisfied":status==nw_path_status_satisfiable?@"requires_connection":@"unsatisfied",@"networkOnline":status==nw_path_status_satisfied?@YES:@NO,@"wifi":@(nw_path_uses_interface_type(path,nw_interface_type_wifi))});
  dispatch_async(GSCoreQueue,^{GSConditions();});
 });
 // Do not starve path callbacks behind SSO / Google endpoint validation.
 nw_path_monitor_set_queue(GSMonitor,dispatch_queue_create("dev.tqmane.gunshot.network",DISPATCH_QUEUE_SERIAL));nw_path_monitor_start(GSMonitor);
 });
}
NSDictionary *GSRequest(NSDictionary *request,NSError **error) {
 GSStart();
 // Repair missed lifecycle notifications when a settings page starts polling.
 if(NSThread.isMainThread)GSSampleApplication();else dispatch_async(dispatch_get_main_queue(),^{GSSampleApplication();});
 __block NSDictionary *result=nil;
 dispatch_sync(GSCoreQueue,^{
 if(!GSReady)return;
 NSString *op=request[@"op"];
 if([op isEqual:@"conditions"])return;
 GSConditions();
 BOOL native=[op isEqual:@"account_native"];
 if(native)GSRecord(@{@"authorization":@"checking"});
 result=GSCall(request,[@[@"begin",@"append",@"seal"]containsObject:op]?"googlephotos":"settings");
 if(native)GSRecord(@{@"authorization":result?@"validated":@"failed"});
 });
 if(!result&&error)*error=[NSError errorWithDomain:@"Gunshot" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GoToHP request failed. Check the account, storage and queue in this app."}];
 return result;
}
