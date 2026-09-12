#import "GSPanel.h"
#import "GSExporter.h"
#import "GSNativeRouting.h"
#import "GSUploadDiagnostics.h"
#import "../Shared/IPCProtocol.h"
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>
#if GS_JAILED
#define GS_ACCOUNT_HELP @"Add an account using GoToHP → Settings → Account in this app."
#define GS_QUEUED_HELP @"Keep this app in the foreground to upload. Pending jobs resume when reopened."
#define GS_AUTH_HELP @"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. It is stored privately in this app and sent to Google. It is never displayed again."
#else
#define GS_ACCOUNT_HELP @"Open Settings → GoToHP and add an account first."
#define GS_QUEUED_HELP @"Background upload continues in gotohpd."
#define GS_AUTH_HELP @"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. The value is sent only to gotohpd and Google. It is never displayed again."
#endif
@interface GSPanel () <PHPickerViewControllerDelegate>
@property(nonatomic,strong) NSArray *jobs;
@property(nonatomic,strong) NSDictionary *accounts;
@property(nonatomic,strong) NSMutableDictionary *options;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) BOOL busy;
@property(nonatomic,strong) NSArray *sharedItems;
@property(nonatomic,strong) NSArray *routedAssets;
@property(nonatomic,copy) NSString *routeAccount;
@property(nonatomic,copy) void (^activityCompletion)(void);
@property(nonatomic,copy) NSString *statusText;
@end
@implementation GSPanel
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"GoToHP";self.jobs=@[];self.statusText=@"Connecting…";
 self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:self.settingsMode?@"Account":@"Upload" style:UIBarButtonItemStylePlain target:self action:@selector(primary)];
#if GS_JAILED
 self.navigationItem.prompt=@"Jailed: uploads require this app in the foreground.";
#endif
 if(!self.settingsMode&&GSIsGooglePhotos()){
 UIBarButtonItem *settings=[[UIBarButtonItem alloc]initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(openEmbeddedSettings)];
 self.navigationItem.rightBarButtonItems=@[self.navigationItem.rightBarButtonItem,settings];
 }
 self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=64;
 [self refresh];
}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];__weak GSPanel *weak=self;self.timer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t){[weak refresh];}];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (void)openEmbeddedSettings{
 if(self.busy)return;
 GSPanel *settings=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];settings.settingsMode=YES;
 [self.navigationController pushViewController:settings animated:YES];
}
- (void)close{if(!self.busy){if(self.navigationController.viewControllers.count>1){[self.navigationController popViewControllerAnimated:YES];return;}if(self.activityCompletion)self.activityCompletion();else[self dismissViewControllerAnimated:YES completion:nil];}}
- (void)message:(NSString *)message{self.statusText=message;[self.tableView reloadData];}
- (void)refresh{
 if(self.busy)return;self.busy=YES;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;
 NSMutableArray *jobs=[NSMutableArray array];NSInteger cursor=0;NSDictionary *page=nil;
 if(options)do{page=GSRequest(@{@"op":@"list",@"cursor":@(cursor)},&error);if(!page)break;[jobs addObjectsFromArray:page[@"jobs"]?:@[]];cursor=[page[@"next"]integerValue];}while(cursor>=0);
 dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;if(error){[self message:error.localizedDescription];return;}self.accounts=accounts;self.options=[options mutableCopy];self.jobs=jobs;
 self.statusText=[NSString stringWithFormat:@"%@ · %@ · %@",accounts[@"selected"]?:@"Add account in Settings",options[@"quality"]?:@"original",[page[@"online"]boolValue]?@"Online":@"Offline / waiting"];
 [self.tableView reloadData];
 if(self.routedAssets){NSArray *assets=self.routedAssets;self.routedAssets=nil;
 if(!assets.count){[self message:@"GoToHP could not resolve this selection. Native backup was not started. Use GoToHP → Upload."];return;}
 if(![self.routeAccount isEqualToString:accounts[@"selected"]]){[self message:@"The GoToHP destination account changed. Re-enable routing in GoToHP Settings. Native backup was not started."];return;}
 [self importAssets:assets];
 }
 });
 });
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 3;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return section==0?1:section==1?(self.settingsMode?(GSIsGooglePhotos()?13:10):1):self.jobs.count;}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{return section==0?@"Status":section==1?@"Controls":@"Upload queue";}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.textLabel.numberOfLines=0;c.detailTextLabel.numberOfLines=0;
 if(path.section==0)c.textLabel.text=self.statusText;
 else if(path.section==1){
 NSArray *titles=@[@"Quality",@"Concurrent uploads",@"Retry count",@"Wi-Fi only",@"Charging only",@"Pause uploads",@"Select account",@"Remove account",@"Retry all failed",@"Clear completed",@"Route Google Photos backup action",@"Upload compatibility diagnostics",@"Export upload diagnostics"];
 c.textLabel.text=self.settingsMode?titles[path.row]:@"Choose photos / videos";
 if(self.settingsMode&&path.row==11)c.detailTextLabel.text=GSUploadDiagnosticsAvailable()?(GSUploadDiagnosticsEnabled()?@"On · metadata only, last 256 events":@"Off · observation only; no upload replacement"):@"Unavailable for this app version";
 if(self.settingsMode&&path.row==10)c.detailTextLabel.text=GSNativeRoutingAvailable()?(GSNativeRoutingEnabled()?@"On · manual Back up now → GoToHP":@"Off · manual Back up now only"):@"Unavailable · requires Google Photos 7.92.0 with matching methods";
 if(self.settingsMode&&path.row<6){NSArray *keys=@[@"quality",@"concurrent",@"retries",@"wifiOnly",@"chargingOnly",@"paused"];c.detailTextLabel.text=[self.options[keys[path.row]]description];}
 }else{NSDictionary *j=self.jobs[path.row];c.textLabel.text=[NSString stringWithFormat:@"%@ · %@",j[@"resources"][0][@"name"],j[@"state"]];c.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@ / %@ bytes\n%@",j[@"quality"],j[@"uploaded"],j[@"total"],j[@"error"]?:@""];}
 return c;
}
- (void)request:(NSDictionary *)request{
 if(self.busy)return;self.busy=YES;self.navigationItem.rightBarButtonItem.enabled=NO;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;GSRequest(request,&error);dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.navigationItem.rightBarButtonItem.enabled=YES;if(error)[self message:error.localizedDescription];else[self refresh];});});
}
- (void)sheet:(UIAlertController *)sheet{sheet.popoverPresentationController.sourceView=self.view;sheet.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);[self presentViewController:sheet animated:YES completion:nil];}
- (void)primary{if(self.busy)return;if(self.settingsMode)[self addAccount];else if(self.sharedItems.count){NSArray *items=self.sharedItems;self.sharedItems=nil;if([items.firstObject isKindOfClass:PHAsset.class])[self importAssets:items];else[self importURLs:items];}else[self choose];}
- (void)addAccount{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Add Google account" message:GS_AUTH_HELP preferredStyle:UIAlertControllerStyleAlert];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.secureTextEntry=YES;f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.placeholder=@"oauth_token / credential";}];
 [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:@"Connect" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSString *secret=a.textFields.firstObject.text;a.textFields.firstObject.text=@"";[self request:@{@"op":@"account_add",@"secret":secret?:@""}];}]];[self sheet:a];
}
- (void)exportUploadDiagnostics{
 NSData *json=[NSJSONSerialization dataWithJSONObject:GSUploadDiagnosticsSnapshot() options:NSJSONWritingPrettyPrinted error:nil];
 NSURL *file=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gotohp-upload-diagnostics.json"]];
 if(!json||![json writeToURL:file options:NSDataWritingAtomic error:nil]){[self message:@"Could not export upload diagnostics."];return;}
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[file] applicationActivities:nil];
 share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);
 [self presentViewController:share animated:YES completion:nil];
}
- (void)toggleNativeRouting{
 if(!GSNativeRoutingAvailable()){[self message:@"This Google Photos version does not have a supported backup action hook. Use GoToHP → Upload."];return;}
 if(GSNativeRoutingEnabled()){GSSetNativeRouting(NO,nil);[self.tableView reloadData];return;}
 NSString *account=self.accounts[@"selected"];
 if(!account.length){[self message:GS_ACCOUNT_HELP];return;}
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Route Back up now to GoToHP?" message:[NSString stringWithFormat:@"Destination: %@\nOnly the standard manual backup action in Google Photos 7.92.0 is redirected. Turn off Google Photos automatic backup to avoid independent native uploads. Sharing, locked folders and other upload paths are not redirected. Progress is shown in GoToHP; Google Photos backup status is not forged.",account] preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:@"Enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){GSSetNativeRouting(YES,account);[self.tableView reloadData];}]];[self sheet:a];
}
- (void)accountAction:(BOOL)remove{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:remove?@"Remove account":@"Select account" message:remove?@"Cancel unfinished jobs for this account first.":nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSDictionary *account in self.accounts[@"accounts"]){NSString *email=account[@"email"];[a addAction:[UIAlertAction actionWithTitle:email style:remove?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":remove?@"account_remove":@"account_select",@"account":email}];}]];}
 [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path{
 [tableView deselectRowAtIndexPath:path animated:YES];if(self.busy)return;
 if(path.section==1){
 if(!self.settingsMode){[self choose];return;}
 if(path.row==10){[self toggleNativeRouting];return;}
 if(path.row==11){GSSetUploadDiagnostics(!GSUploadDiagnosticsEnabled());[self.tableView reloadData];return;}
 if(path.row==12){[self exportUploadDiagnostics];return;}
 if(path.row<6){NSMutableDictionary *o=[self.options mutableCopy];if(!o)return;
 switch(path.row){case 0:{NSArray *v=@[@"original",@"saver",@"quota"];NSUInteger i=[v indexOfObject:o[@"quality"]];o[@"quality"]=v[(i+1)%3];break;}case 1:o[@"concurrent"]=@([o[@"concurrent"]integerValue]%4+1);break;case 2:o[@"retries"]=@(([o[@"retries"]integerValue]+1)%11);break;default:{NSArray *keys=@[@"wifiOnly",@"chargingOnly",@"paused"];NSString *k=keys[path.row-3];o[k]=@(![o[k]boolValue]);break;}}
 [self request:@{@"op":@"configure",@"options":o}];
 }else if(path.row==6||path.row==7)[self accountAction:path.row==7];else [self request:@{@"op":path.row==8?@"retry_failed":@"clear_completed"}];
 }else if(path.section==2){NSDictionary *j=self.jobs[path.row];NSString *state=j[@"state"];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:j[@"resources"][0][@"name"] message:j[@"error"] preferredStyle:UIAlertControllerStyleActionSheet];
 if([state isEqual:@"failed"])[a addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":@"retry",@"id":j[@"id"]}];}]];
 if(![state isEqual:@"completed"]&&![state isEqual:@"cancelled"])[a addAction:[UIAlertAction actionWithTitle:@"Cancel upload" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[self request:@{@"op":@"cancel",@"id":j[@"id"]}];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
 }
}
- (void)choose{
 if(![self.accounts[@"selected"]length]){[self message:GS_ACCOUNT_HELP];return;}
 if(![NSBundle.mainBundle objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]){[self message:@"The host app must include NSPhotoLibraryUsageDescription before photo access can be requested."];return;}
 [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status){dispatch_async(dispatch_get_main_queue(),^{
 if(status!=PHAuthorizationStatusAuthorized&&status!=PHAuthorizationStatusLimited){[self message:@"Photo library permission is required."];return;}
 PHPickerConfiguration *c=[[PHPickerConfiguration alloc]initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];c.selectionLimit=0;c.preferredAssetRepresentationMode=PHPickerConfigurationAssetRepresentationModeCurrent;
 PHPickerViewController *picker=[[PHPickerViewController alloc]initWithConfiguration:c];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];
 });}];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
 [picker dismissViewControllerAnimated:YES completion:^{NSMutableArray *ids=[NSMutableArray array];for(PHPickerResult *r in results)if(r.assetIdentifier)[ids addObject:r.assetIdentifier];
 PHFetchResult *found=[PHAsset fetchAssetsWithLocalIdentifiers:ids options:nil];NSMutableArray *assets=[NSMutableArray array];[found enumerateObjectsUsingBlock:^(PHAsset *a,NSUInteger i,BOOL *stop){[assets addObject:a];}];
 if(assets.count!=results.count)[self message:@"Some selected assets are outside the permitted photo library. Expand limited access and select again."];else if(assets.count)[self importAssets:assets];}];
}
- (void)importAssets:(NSArray<PHAsset *> *)assets{[self importItems:assets assets:YES];}
- (void)importURLs:(NSArray<NSURL *> *)urls{[self importItems:urls assets:NO];}
- (void)importItems:(NSArray *)items assets:(BOOL)areAssets{
 if(self.busy){[self message:@"Please wait for the current operation, then try again."];return;}self.busy=YES;
 __block BOOL expired=NO;__block UIBackgroundTaskIdentifier task=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{@synchronized(self){expired=YES;}}];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;NSUInteger queued=0;
 if(self.routeAccount&&![self.routeAccount isEqualToString:accounts[@"selected"]])error=[NSError errorWithDomain:@"Gunshot" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GoToHP destination account changed. Re-enable routing in Settings."}];
 for(id item in items){@autoreleasepool{
 @synchronized(self){if(expired)break;}if(error)break;
 NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];if(error)break;
 NSArray *files=nil;NSDate *date=nil;BOOL scoped=NO;
 if(areAssets){PHAsset *asset=item;date=asset.creationDate;files=GSExportAsset(asset,dir,&error);}else{NSURL *url=item;scoped=[url startAccessingSecurityScopedResource];files=@[url];NSDictionary *attr=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];date=attr[NSFileModificationDate];}
 NSString *identifier=files?GSImportFiles(files,accounts[@"selected"],options[@"quality"],date,&error):nil;
 if(scoped)[item stopAccessingSecurityScopedResource];[NSFileManager.defaultManager removeItemAtURL:dir error:nil];
 if(!identifier)break;queued++;NSUInteger count=queued;
 dispatch_async(dispatch_get_main_queue(),^{[self message:[NSString stringWithFormat:@"Queued %lu / %lu. Keep the app open until preparation finishes.",(unsigned long)count,(unsigned long)items.count]];});
 }}
 dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;if(task!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:task];task=UIBackgroundTaskInvalid;}
 [self message:[NSString stringWithFormat:@"%lu / %lu queued. %@",(unsigned long)queued,(unsigned long)items.count,error?error.localizedDescription:(queued==items.count?GS_QUEUED_HELP:@"Preparation stopped. Select remaining items again.")]];});
 });
}
@end

void GSPresent(UIViewController *host){if(!host)return;GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];[host presentViewController:nav animated:YES completion:nil];}
@interface GSLauncher : NSObject
+ (void)open:(UIButton *)button;
@end
@implementation GSLauncher
+ (void)open:(UIButton *)button{UIViewController *host=button.window.rootViewController;while(host.presentedViewController)host=host.presentedViewController;GSPresent(host);}
@end
static char GSLauncherKey;
void GSInstallButton(UIWindow *window){
 GSInstallNativeRouting();
 GSInstallUploadDiagnostics();
 if(window.windowLevel!=UIWindowLevelNormal||!window.rootViewController||objc_getAssociatedObject(window,&GSLauncherKey))return;
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:@"GoToHP" forState:UIControlStateNormal];button.backgroundColor=UIColor.secondarySystemBackgroundColor;button.layer.cornerRadius=18;button.accessibilityLabel=@"Open GoToHP upload queue";
 [button addTarget:GSLauncher.class action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];button.translatesAutoresizingMaskIntoConstraints=NO;[window addSubview:button];
 [NSLayoutConstraint activateConstraints:@[[button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-12],[button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-65],[button.widthAnchor constraintEqualToConstant:84],[button.heightAnchor constraintEqualToConstant:40]]];
 objc_setAssociatedObject(window,&GSLauncherKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@interface GSUploadActivity ()
@property(nonatomic,strong) NSArray *items;
@end
@implementation GSUploadActivity
- (NSString *)activityType{return @"dev.tqmane.gunshot.upload";}
- (NSString *)activityTitle{return @"Upload with GoToHP";}
- (UIImage *)activityImage{return [UIImage systemImageNamed:@"icloud.and.arrow.up"];}
- (BOOL)canPerformWithActivityItems:(NSArray *)items{if(!items.count)return NO;BOOL assets=[items.firstObject isKindOfClass:PHAsset.class];for(id i in items)if(assets?![i isKindOfClass:PHAsset.class]:!([i isKindOfClass:NSURL.class]&&[i isFileURL]))return NO;return YES;}
- (void)prepareWithActivityItems:(NSArray *)items{self.items=items;}
- (UIViewController *)activityViewController{
 GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];
 panel.sharedItems=self.items;
 __weak GSUploadActivity *weak=self;panel.activityCompletion=^{[weak activityDidFinish:YES];};
 // Use an explicit button so opening the activity does not upload automatically.
 panel.navigationItem.prompt=@"Tap Upload to queue the shared selection.";
 return [[UINavigationController alloc]initWithRootViewController:panel];
}
@end

void GSPresentRoutedAssets(NSArray<PHAsset *> *assets, NSString *account){
 UIViewController *host=nil;
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if([scene isKindOfClass:UIWindowScene.class])
  for(UIWindow *window in ((UIWindowScene *)scene).windows)if(window.isKeyWindow&&window.windowLevel==UIWindowLevelNormal)host=window.rootViewController;
 while(host.presentedViewController)host=host.presentedViewController;
 if(!host)return; // Native upload remains suppressed; user may select again in GoToHP.
 GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];panel.routedAssets=assets;panel.routeAccount=account?:@"";
 [host presentViewController:[[UINavigationController alloc]initWithRootViewController:panel] animated:YES completion:nil];
}
