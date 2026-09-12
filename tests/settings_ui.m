#import <UIKit/UIKit.h>
#import "../UI/GSPanel.h"
#import "../UI/GSNativeRouting.h"
#import "../UI/GSUploadDiagnostics.h"
#import "../UI/GSExporter.h"
#import "../Shared/IPCProtocol.h"
#include <stdlib.h>
// Real jailed adapter + UIKit + NWPath; only the Go/Google boundary is a fake.
// A synchronous main callback models native SSO while the core queue is busy.
static NSDictionary *Conditions;
static BOOL SnapshotDuringAuthorization;
NSDictionary *GSNativeAccountSummary(void){return @{@"email":@"test@example.com",@"identifier":@"fixture"};}
char *GSNativeBearer(const char *identifier){return NULL;}
void GunshotSetHostBearerProvider(uintptr_t provider){}
int GunshotInitialize(char *path){return 0;}
void GunshotFree(void *value){free(value);}
char *GunshotRequest(char *json,char *role){
 NSDictionary *request=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:json]dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 NSString *op=request[@"op"];id data=@{};
 if([op isEqual:@"conditions"])Conditions=request;
 if([op isEqual:@"account_native"]){
  NSLog(@"Fixture: authorizing");
  dispatch_sync(dispatch_get_main_queue(),^{
   NSDictionary *snapshot=GSEmbeddedRuntimeSnapshot();
   SnapshotDuringAuthorization=[snapshot[@"authorization"]isEqual:@"checking"];
   NSLog(@"Fixture: authorization snapshot returned");
  });
 }
 if([op isEqual:@"accounts"])data=@{@"selected":@"test@example.com",@"accounts":@[@{@"email":@"test@example.com"}]};
 if([op isEqual:@"options"])data=@{@"quality":@"original",@"concurrent":@2,@"retries":@3,@"wifiOnly":@NO,@"chargingOnly":@NO,@"paused":@NO};
 if([op isEqual:@"list"])data=@{@"jobs":@[],@"next":@(-1),@"online":Conditions[@"online"]?:@NO,@"wifi":Conditions[@"wifi"]?:@NO};
 NSData *reply=[NSJSONSerialization dataWithJSONObject:@{@"ok":@YES,@"data":data} options:0 error:nil];
 return strdup([[NSString alloc]initWithData:reply encoding:NSUTF8StringEncoding].UTF8String);
}
BOOL GSIsGooglePhotos(void){return YES;}
void GSInstallNativeRouting(void){}
BOOL GSNativeRoutingAvailable(void){return YES;}
BOOL GSNativeRoutingEnabled(void){return NO;}
NSString *GSNativeRoutingAccount(void){return @"test@example.com";}
void GSSetNativeRouting(BOOL enabled,NSString *account){}
void GSInstallUploadDiagnostics(void){}
BOOL GSUploadDiagnosticsAvailable(void){return YES;}
BOOL GSUploadDiagnosticsEnabled(void){return NO;}
void GSSetUploadDiagnostics(BOOL enabled){}
NSDictionary *GSUploadDiagnosticsSnapshot(void){return @{};}
NSArray<NSURL *> *GSExportAsset(PHAsset *asset,NSURL *directory,NSError **error){return nil;}
NSString *GSImportFiles(NSArray<NSURL *> *files,NSString *account,NSString *quality,NSDate *date,NSError **error){return nil;}
static NSString *Documents(void){return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;}
static void Finish(BOOL success,NSString *reason){
 [[NSString stringWithFormat:@"%@ %@\n",success?@"PASS":@"FAIL",reason]writeToFile:[Documents() stringByAppendingPathComponent:@"result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 NSLog(@"Settings UIKit smoke: %@",reason);exit(success?0:1);
}
static void Await(BOOL(^condition)(void),void(^next)(void),NSDate *deadline){
 if(condition()){next();return;}
 if(deadline.timeIntervalSinceNow<=0){Finish(NO,@"presentation deadline exceeded");return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{Await(condition,next,deadline);});
}
static void Capture(UIWindow *window,NSString *name){
 UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:window.bounds.size];
 NSData *png=[renderer PNGDataWithActions:^(UIGraphicsImageRendererContext *context){[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];}];
 [png writeToFile:[Documents() stringByAppendingPathComponent:name] atomically:YES];
}
static GSPanel *Panel(UIViewController *host){
 UIViewController *nav=host.presentedViewController;
 if(![nav isKindOfClass:UINavigationController.class])return nil;
 id top=((UINavigationController *)nav).topViewController;return [top isKindOfClass:GSPanel.class]?top:nil;
}
@interface GSFixtureScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic) BOOL started;
@end
@implementation GSFixtureScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{
 NSLog(@"Fixture: scene connecting");
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];
 self.window.rootViewController=[UIViewController new];self.window.rootViewController.view.backgroundColor=UIColor.systemBackgroundColor;
 [self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene{
 if(self.started)return;self.started=YES;NSLog(@"Fixture: scene active");
 UIViewController *root=self.window.rootViewController;
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:30];
 // A detached delegate controller must resolve to the active scene's root.
 GSPresentSettings([UIViewController new]);
 Await(^BOOL{GSPanel *panel=Panel(root);return panel.settingsMode&&panel.viewIfLoaded.window&&[[panel.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].detailTextLabel.text isEqual:@"認証確認済み · アップロード可能"];},^{
  NSDictionary *runtime=GSEmbeddedRuntimeSnapshot();
  if(!SnapshotDuringAuthorization||![runtime[@"coreReady"]boolValue]||![runtime[@"foreground"]boolValue]||![runtime[@"path"]isEqual:@"satisfied"]){Finish(NO,@"embedded runtime state or nonblocking authorization snapshot failed");return;}
  NSSet *allowed=[NSSet setWithArray:@[@"coreReady",@"foreground",@"path",@"networkOnline",@"wifi",@"charging",@"authorization"]];
  if(![[NSSet setWithArray:runtime.allKeys]isSubsetOfSet:allowed]){Finish(NO,@"unexpected diagnostic fields");return;}
  GSPanel *panel=Panel(root);if([panel.tableView numberOfSections]!=7){Finish(NO,@"settings sections missing");return;}
  Capture(self.window,@"settings-light.png");
  [panel.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:6] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
  Capture(self.window,@"settings-history.png");
  [root dismissViewControllerAnimated:NO completion:^{
   UIViewController *menu=[UIViewController new];menu.view.backgroundColor=UIColor.secondarySystemBackgroundColor;
   [root presentViewController:menu animated:NO completion:^{
    GSPresentSettings(root); // Root already has a presented account menu.
    Await(^BOOL{return Panel(menu).viewIfLoaded.window!=nil;},^{
     UIViewController *first=menu.presentedViewController;
     GSPresentSettings(root);GSPresentSettings(nil);
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
      if(menu.presentedViewController!=first||first.presentedViewController){Finish(NO,@"duplicate settings presentation");return;}
      self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
      Capture(self.window,@"settings-dark.png");
      [root dismissViewControllerAnimated:NO completion:^{
       GSPresentSettings(nil);
       Await(^BOOL{return Panel(root).viewIfLoaded.window!=nil;},^{Finish(YES,@"detached, nested, repeated and nil-host presentation; settings rendered; real jailed runtime online and authorization snapshot nonblocking");},deadline);
      }];
     });
    },deadline);
   }];
  }];
 },deadline);
}
@end
@interface GSFixtureApp : UIResponder <UIApplicationDelegate> @end
@implementation GSFixtureApp
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{
 UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:@"Fixture" sessionRole:session.role];config.delegateClass=GSFixtureScene.class;return config;
}
@end
int main(int argc,char **argv){@autoreleasepool{
 NSLog(@"Fixture: main");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{Finish(NO,@"watchdog: no completion within 60 seconds after main");});
 return UIApplicationMain(argc,argv,nil,NSStringFromClass(GSFixtureApp.class));
}}
