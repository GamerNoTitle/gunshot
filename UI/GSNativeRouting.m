#import "GSNativeRouting.h"
#if GS_JAILED
#import "GSBackupRequests.h"
#endif
#import <objc/runtime.h>
#import <objc/message.h>

// Audited from 7.92.0's ObjC metadata; this is the explicit backup UI action,
// not the automatic-backup engine or its server completion callbacks.
static BOOL GSInstalled;
static NSString *const GSEnabledKey=@"dev.tqmane.gunshot.routeManualBackup";
static NSString *const GSAccountKey=@"dev.tqmane.gunshot.routeAccount";
static void (*GSBackupOriginal)(id,SEL,id);
static void (*GSGridBackupOriginal)(id,SEL,id);
BOOL GSIsGooglePhotos(void){return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqualToString:@"GooglePhotos"];}
BOOL GSNativeRoutingAvailable(void){return GSInstalled;}
BOOL GSNativeRoutingEnabled(void){return GSInstalled&&[NSUserDefaults.standardUserDefaults boolForKey:GSEnabledKey];}
NSString *GSNativeRoutingAccount(void){return [NSUserDefaults.standardUserDefaults stringForKey:GSAccountKey];}
void GSSetNativeRouting(BOOL enabled, NSString *account){
 [NSUserDefaults.standardUserDefaults setObject:account?:@"" forKey:GSAccountKey];
 [NSUserDefaults.standardUserDefaults setBool:enabled&&GSInstalled forKey:GSEnabledKey];
}
static void GSRoute(id localAssets){
 NSMutableArray *assets=[NSMutableArray array];BOOL valid=[localAssets isKindOfClass:NSArray.class]||[localAssets isKindOfClass:NSSet.class];
 if(valid)for(id local in localAssets){
  PHAsset *asset=nil;
  if([local isKindOfClass:PHAsset.class])asset=local;
  else if([local isKindOfClass:NSClassFromString(@"PHSLocalAsset")]){
   if(((BOOL(*)(id,SEL))objc_msgSend)(local,NSSelectorFromString(@"isLocked"))){valid=NO;break;}
   asset=((id(*)(id,SEL))objc_msgSend)(local,NSSelectorFromString(@"phAsset"));
  }
  if(![asset isKindOfClass:PHAsset.class]){valid=NO;break;}
  [assets addObject:asset];
 }
 // A routed action NEVER falls back to a native upload if export/queueing fails.
 // An empty selection presents an explanatory error instead of reporting success.
 NSString *account=GSNativeRoutingAccount();
 dispatch_async(dispatch_get_main_queue(),^{GSPresentRoutedAssets(valid?assets:@[],account);});
}
static void GSBackup(id object,SEL selector,id assets){
 if(!GSNativeRoutingEnabled()){GSBackupOriginal(object,selector,assets);return;}
#if GS_JAILED
 // Keep the native scheduler/delegate alive. The common request hook owns the
 // Go handoff and subsequent server reconciliation, including manual actions.
 if(GSBackupRequestsAvailable()){GSBackupOriginal(object,selector,assets);return;}
#endif
 GSRoute(assets);
}
static void GSGridBackup(id object,SEL selector,id assets){
 if(!GSNativeRoutingEnabled()){GSGridBackupOriginal(object,selector,assets);return;}
#if GS_JAILED
 if(GSBackupRequestsAvailable()){GSGridBackupOriginal(object,selector,assets);return;}
#endif
 GSRoute(assets);
}
void GSInstallNativeRouting(void){
#if GS_JAILED
 GSInstallBackupRequests();
#endif
 // Called on the main thread when installing the app's GoToHP launcher.
 if(GSInstalled||!GSIsGooglePhotos()||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqualToString:@"7.92.0"])return;
 Class behavior=NSClassFromString(@"PHSBackupActionBehaviorImpl");
 Class grid=NSClassFromString(@"PHSActionsGridModel");
 Class local=NSClassFromString(@"PHSLocalAsset");
 SEL selector=NSSelectorFromString(@"backupLocalAssets:");
 Method a=class_getInstanceMethod(behavior,selector),b=class_getInstanceMethod(grid,selector);
 Method asset=class_getInstanceMethod(local,NSSelectorFromString(@"phAsset"));
 Method locked=class_getInstanceMethod(local,NSSelectorFromString(@"isLocked"));
 if(!a||!b||!asset||!locked||strcmp(method_getTypeEncoding(a),"v24@0:8@16")||strcmp(method_getTypeEncoding(b),"v24@0:8@16")||strcmp(method_getTypeEncoding(asset),"@16@0:8")||strcmp(method_getTypeEncoding(locked),"B16@0:8"))return;
 GSBackupOriginal=(void *)method_setImplementation(a,(IMP)GSBackup);
 GSGridBackupOriginal=(void *)method_setImplementation(b,(IMP)GSGridBackup);
 GSInstalled=YES;
}
