#import "../Shared/IPCProtocol.h"
#import <UIKit/UIKit.h>
#import <Network/Network.h>
#import "libgotohp.h"

// This adapter exposes no socket, Mach service, or external account API.
// The caller is already inside the host sandbox; role selection stays native.
static dispatch_queue_t GSCoreQueue;
static BOOL GSReady, GSForeground, GSOnline, GSWifi, GSCharging;
static nw_path_monitor_t GSMonitor;
static NSDictionary *GSCall(NSDictionary *request, const char *role) {
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
 if(GSReady)GSCall(@{@"op":@"conditions",@"online":@(GSForeground&&GSOnline),@"wifi":@(GSWifi),@"charging":@(GSCharging)},"daemon");
}
static void GSSampleApplication(void) {
 // UIKit state is read only on the main thread. Worker state is queue-confined.
 BOOL foreground=UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground;
 UIDeviceBatteryState state=UIDevice.currentDevice.batteryState;
 BOOL charging=state==UIDeviceBatteryStateCharging||state==UIDeviceBatteryStateFull;
 dispatch_async(GSCoreQueue,^{GSForeground=foreground;GSCharging=charging;GSConditions();});
}
static void GSStart(void) {
 static dispatch_once_t once;
 dispatch_once(&once,^{
 GSCoreQueue=dispatch_queue_create("dev.tqmane.gunshot.embedded",DISPATCH_QUEUE_SERIAL);
 // Resolve through Foundation AFTER LC has installed the guest data container.
 // Never use a fixed /var/mobile or /var/jb path in the jailed target.
 NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *root=[support URLByAppendingPathComponent:@"GoToHP" isDirectory:YES];
 dispatch_async(GSCoreQueue,^{
 NSError *error=nil;
 if(!root||![NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700,NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:&error])return;
 [root setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
 GSReady=GunshotInitialize((char *)root.path.UTF8String)==0;
 GSConditions();
 });
 dispatch_async(dispatch_get_main_queue(),^{
 UIDevice.currentDevice.batteryMonitoringEnabled=YES;
 NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
 for(NSString *name in @[UIApplicationDidBecomeActiveNotification,UIApplicationDidEnterBackgroundNotification,UIDeviceBatteryStateDidChangeNotification])
  [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){GSSampleApplication();}];
 GSSampleApplication();
 });
 GSMonitor=nw_path_monitor_create();
 nw_path_monitor_set_update_handler(GSMonitor,^(nw_path_t path){GSOnline=nw_path_get_status(path)==nw_path_status_satisfied;GSWifi=nw_path_uses_interface_type(path,nw_interface_type_wifi);GSConditions();});
 nw_path_monitor_set_queue(GSMonitor,GSCoreQueue);nw_path_monitor_start(GSMonitor);
 });
}
NSDictionary *GSRequest(NSDictionary *request, NSError **error) {
 GSStart();
 __block NSDictionary *result=nil;
 dispatch_sync(GSCoreQueue,^{
 if(!GSReady)return;
 NSString *op=request[@"op"];
 // User requests cannot alter runtime conditions. They come only from UIKit/NWPath.
 if([op isEqual:@"conditions"])return;
 BOOL importing=[@[@"begin",@"append",@"seal"]containsObject:op];
 result=GSCall(request,importing?"googlephotos":"settings");
 });
 if(!result&&error)*error=[NSError errorWithDomain:@"Gunshot" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GoToHP request failed. Check the account, storage and queue in this app."}];
 return result;
}
