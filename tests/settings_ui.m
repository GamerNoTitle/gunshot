#import <UIKit/UIKit.h>
#import "../UI/GSPanel.h"
#import "../UI/GSNativeRouting.h"
#import "../UI/GSUploadDiagnostics.h"
#import "../UI/GSExporter.h"
#import "../Shared/IPCProtocol.h"
#include <stdlib.h>
// Simulator-only service: never imports a credential, contacts Google or uploads.
NSDictionary *GSRequest(NSDictionary *request,NSError **error){
 NSString *op=request[@"op"];
 if([op isEqual:@"accounts"])return @{@"selected":@"test@example.com",@"accounts":@[@{@"email":@"test@example.com"}]};
 if([op isEqual:@"options"])return @{@"quality":@"original",@"concurrent":@2,@"retries":@3,@"wifiOnly":@YES,@"chargingOnly":@NO,@"paused":@NO};
 if([op isEqual:@"list"])return @{@"jobs":@[],@"next":@(-1),@"online":@YES};
 return @{};
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
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];
 self.window.rootViewController=[UIViewController new];self.window.rootViewController.view.backgroundColor=UIColor.systemBackgroundColor;
 [self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene{
 if(self.started)return;self.started=YES;
 UIViewController *root=self.window.rootViewController;
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:30];
 // A detached delegate controller must resolve to the active scene's root.
 GSPresentSettings([UIViewController new]);
 Await(^BOOL{GSPanel *panel=Panel(root);return panel.settingsMode&&panel.viewIfLoaded.window&&[[panel.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].textLabel.text isEqual:@"test@example.com"];},^{
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
       Await(^BOOL{return Panel(root).viewIfLoaded.window!=nil;},^{Finish(YES,@"detached, nested, repeated and nil-host presentation; settings rendered");},deadline);
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
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(GSFixtureApp.class));}}
