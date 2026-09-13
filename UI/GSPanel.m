#import "../Shared/GSLocalization.h"
#import "GSPanel.h"
#import "GSExporter.h"
#import "GSNativeAccount.h"
#import "GSNativeRouting.h"
#import "GSUploadDiagnostics.h"
#import "GSUnlimitedStorage.h"
#if GS_JAILED
#import "GSBackupRequests.h"
#import "GSPhotosIntegration.h"
#endif
#import "../Shared/IPCProtocol.h"
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>
#if GS_JAILED
#define GS_ACCOUNT_HELP GSL(@"Connect or refresh your account.")
#define GS_BACKUP_TITLE GSL(@"Route manual and automatic backups through GoToHP")
#define GS_BACKUP_HELP GSL(@"Enable backup in Google Photos to route automatic backups through GoToHP as well. Uploads use the GoToHP quality setting. Keep the app in the foreground on jailed devices.")
#define GS_QUEUED_HELP GSL(@"Keep this app open while uploading. Pending items resume the next time you open it.")
#define GS_AUTH_HELP GSL(@"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. It is stored privately in this app and sent to Google. It is never displayed again.")
#else
#define GS_BACKUP_TITLE GSL(@"Route manual backups through GoToHP")
#define GS_BACKUP_HELP GSL(@"Applies to the manual Back up now action.")
#define GS_ACCOUNT_HELP GSL(@"Add an account in Settings → GoToHP.")
#define GS_QUEUED_HELP GSL(@"Uploads continue in the background after you close the app.")
#define GS_AUTH_HELP GSL(@"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. The value is sent only to gotohpd and Google. It is never displayed again.")
#endif
@interface GSPanel () <PHPickerViewControllerDelegate>
@property(nonatomic,strong) NSArray *jobs;
@property(nonatomic,strong) NSDictionary *accounts;
@property(nonatomic,strong) NSMutableDictionary *options;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL refreshing;
@property(nonatomic) NSUInteger stateGeneration;
@property(nonatomic) BOOL nativeAuthorizationFailed;
@property(nonatomic,strong) NSArray *sharedItems;
@property(nonatomic,copy) void (^activityCompletion)(void);
@property(nonatomic,copy) NSString *statusText;
@property(nonatomic,copy) NSString *statusLanguage;
@end
@implementation GSPanel
- (void)viewDidLoad{
 [super viewDidLoad];GSInstallNativeRouting();GSInstallUploadDiagnostics();GSInstallUnlimitedStorage();self.title=@"GoToHP";self.jobs=@[];self.statusText=GSL(@"Checking the connection…");self.statusLanguage=GSLanguage();
 self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:GSL(@"Done") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:self.settingsMode?GSL(@"Reconnect"):GSL(@"Add") style:UIBarButtonItemStylePlain target:self action:@selector(primary)];
#if !GS_JAILED
 if(self.settingsMode)self.navigationItem.rightBarButtonItem.title=GSL(@"Account");
#endif
#if GS_JAILED
 self.navigationItem.prompt=nil;
#endif
 if(self.settingsMode&&GSIsGooglePhotos()){
 UIBarButtonItem *upload=[[UIBarButtonItem alloc]initWithTitle:GSL(@"Uploads") style:UIBarButtonItemStylePlain target:self action:@selector(openUploadPanel)];
 self.navigationItem.rightBarButtonItems=@[self.navigationItem.rightBarButtonItem,upload];
 }
 if(!self.settingsMode&&GSIsGooglePhotos()){
 UIBarButtonItem *settings=[[UIBarButtonItem alloc]initWithTitle:GSL(@"Settings") style:UIBarButtonItemStylePlain target:self action:@selector(openEmbeddedSettings)];
 self.navigationItem.rightBarButtonItems=@[self.navigationItem.rightBarButtonItem,settings];
 }
 self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=72;
 self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
 self.tableView.tintColor=[UIColor colorWithRed:0.10 green:0.45 blue:0.91 alpha:1];
 self.navigationController.navigationBar.tintColor=self.tableView.tintColor;
#if GS_JAILED
 if(GSIsGooglePhotos()&&GSNativeAccountSummary()){[self connectNativeAccount];return;}
#endif
 [self refresh];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self updateNavigationLabels];[self reloadTablePreservingPosition];}
- (void)updateNavigationLabels{
 self.navigationItem.leftBarButtonItem.title=GSL(@"Done");
 self.navigationItem.rightBarButtonItem.title=self.settingsMode?GSL(@"Reconnect"):GSL(@"Add");
#if !GS_JAILED
 if(self.settingsMode)self.navigationItem.rightBarButtonItem.title=GSL(@"Account");
#endif
 if(self.navigationItem.rightBarButtonItems.count>1)self.navigationItem.rightBarButtonItems[1].title=self.settingsMode?GSL(@"Uploads"):GSL(@"Settings");
}
- (void)chooseLanguage{
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:GSL(@"Language") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 NSArray *codes=@[@"system",@"ja",@"en"],*names=@[GSL(@"System default"),GSL(@"Japanese"),@"English"];
 for(NSUInteger i=0;i<codes.count;i++){NSString *code=codes[i];NSString *title=[code isEqual:GSLanguageOverride()]?[@"✓ " stringByAppendingString:names[i]]:names[i];
  [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){GSSetLanguage(code);[self updateNavigationLabels];[self reloadTablePreservingPosition];[self refresh];}]];
 }
 [sheet addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];[self sheet:sheet];
}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];__weak GSPanel *weak=self;self.timer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t){[weak refresh];}];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (void)openUploadPanel{
 if(self.busy)return;
 GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];
 [self.navigationController pushViewController:panel animated:YES];
}
- (void)openEmbeddedSettings{
 if(self.busy)return;
 GSPanel *settings=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];settings.settingsMode=YES;
 [self.navigationController pushViewController:settings animated:YES];
}
- (void)close{
 // Closing the screen does not cancel queued work or wait for authentication.
 if(self.navigationController.viewControllers.count>1){[self.navigationController popViewControllerAnimated:YES];return;}
 if(self.activityCompletion)self.activityCompletion();else[self dismissViewControllerAnimated:YES completion:nil];
}
- (BOOL)isInteractingWithTable{return self.tableView.tracking||self.tableView.dragging||self.tableView.decelerating;}
- (void)reloadTablePreservingPosition{
 UITableView *table=self.tableView;
 NSIndexPath *anchor=table.indexPathsForVisibleRows.firstObject;
 CGFloat delta=anchor?table.contentOffset.y-[table rectForRowAtIndexPath:anchor].origin.y:0;
 __block CGPoint offset=table.contentOffset;
 [UIView performWithoutAnimation:^{
  [table reloadData];[table layoutIfNeeded];
  if(anchor&&anchor.section<[table numberOfSections]&&anchor.row<[table numberOfRowsInSection:anchor.section])
   offset.y=[table rectForRowAtIndexPath:anchor].origin.y+delta;
  CGFloat minimum=-table.adjustedContentInset.top;
  CGFloat maximum=MAX(minimum,table.contentSize.height-table.bounds.size.height+table.adjustedContentInset.bottom);
  [table setContentOffset:CGPointMake(offset.x,MIN(MAX(offset.y,minimum),maximum)) animated:NO];
 }];
}
- (void)message:(NSString *)message{
 BOOL changed=![self.statusText isEqual:message]||![self.statusLanguage isEqual:GSLanguage()];
 self.statusText=message;self.statusLanguage=GSLanguage();if(changed)[self reloadTablePreservingPosition];
}
- (void)refresh{
 if(self.busy||self.refreshing||self.nativeAuthorizationFailed||[self isInteractingWithTable])return;self.refreshing=YES;
 NSUInteger generation=self.stateGeneration;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;
 NSMutableArray *jobs=[NSMutableArray array];NSInteger cursor=0;NSDictionary *page=nil;
 if(options)do{page=GSRequest(@{@"op":@"list",@"cursor":@(cursor)},&error);if(!page)break;[jobs addObjectsFromArray:page[@"jobs"]?:@[]];cursor=[page[@"next"]integerValue];}while(cursor>=0);
 dispatch_async(dispatch_get_main_queue(),^{self.refreshing=NO;
 // A poll completing during a gesture is superseded by the next idle poll.
 // Do not change the data source count or invalidate self-sizing rows mid-scroll.
 if([self isInteractingWithTable])return;
 if(generation!=self.stateGeneration){[self refresh];return;}if(error){[self message:error.localizedDescription];return;}
 BOOL changed=![self.accounts isEqual:accounts]||![self.options isEqual:options]||![self.jobs isEqual:jobs];
 NSString *previousStatus=self.statusText,*previousLanguage=self.statusLanguage;
 self.accounts=accounts;self.options=[options mutableCopy];self.jobs=jobs;
 NSString *readiness=GSL(@"Ready to upload");
 if([options[@"paused"]boolValue])readiness=GSL(@"Uploads paused");
 else if(![page[@"online"]boolValue])readiness=GSL(@"Waiting for a connection or app launch");
 else if([options[@"wifiOnly"]boolValue]&&![page[@"wifi"]boolValue])readiness=GSL(@"Waiting for Wi-Fi");
 else if([options[@"chargingOnly"]boolValue]&&![page[@"charging"]boolValue])readiness=GSL(@"Waiting for charging");
 NSString *authorization=GSL(@"Account configured");
#if GS_JAILED
 NSDictionary *runtime=GSEmbeddedRuntimeSnapshot();
 if([runtime[@"authorization"]isEqual:@"validated"])authorization=GSL(@"Authenticated");
 if(![options[@"paused"]boolValue]){
  if(![runtime[@"conditionsAccepted"]boolValue])readiness=GSL(@"Could not apply upload conditions (check diagnostics)");
  else if(![runtime[@"foreground"]boolValue])readiness=GSL(@"Waiting for the app to enter the foreground");
  else if([runtime[@"path"]isEqual:@"unknown"])readiness=GSL(@"Checking network status");
  else if(![runtime[@"networkOnline"]boolValue])readiness=GSL(@"Waiting for a network connection");
 }
#endif
 self.statusText=[accounts[@"selected"]length]?[NSString stringWithFormat:@"%@ · %@",authorization,readiness]:GSL(@"Connect an account to continue");
 NSString *importError=GSNativeRoutingSnapshot()[@"lastError"];if(importError)self.statusText=importError;self.statusLanguage=GSLanguage();
 if(changed||![previousStatus isEqual:self.statusText]||![previousLanguage isEqual:self.statusLanguage])[self reloadTablePreservingPosition];
 });
 });
}
- (NSArray<NSDictionary *> *)controlSections{
 if(!self.settingsMode)return @[@{@"title":GSL(@"Uploads"),@"rows":@[@14],@"footer":GS_QUEUED_HELP}];
 NSMutableArray *groups=[NSMutableArray array];
 NSArray *accountRows=@[@13,@6,@7];
#if GS_JAILED
 if(GSIsGooglePhotos())accountRows=@[@13];
#endif
 [groups addObject:@{@"title":GSL(@"Account"),@"rows":accountRows,@"footer":GSL(@"Connection status and destination appear above.")}];
 [groups addObject:@{@"title":GSL(@"Upload settings"),@"rows":@[@0,@1,@2,@3,@4,@5],@"footer":[GSL(@"Pixel 1 requests original quality without storage usage using the first-generation Pixel XL profile. Quality is saved for each item when queued. Check Google's storage accounting and original-data availability separately.\n") stringByAppendingString:GS_QUEUED_HELP]}];
 if(GSIsGooglePhotos())[groups addObject:@{@"title":GSL(@"Google Photos integration"),@"rows":@[@10],@"footer":GS_BACKUP_HELP}];
 [groups addObject:@{@"title":GSL(@"Queue management"),@"rows":@[@8,@9]}];
 if(GSIsGooglePhotos())[groups addObject:@{@"title":GSL(@"Diagnostics"),@"rows":@[@11,@12],@"footer":GSL(@"For compatibility troubleshooting. Tokens and media contents are never recorded.")}];
 [groups addObject:@{@"title":GSL(@"Appearance"),@"rows":GSIsGooglePhotos()?@[@15,@16]:@[@15],@"footer":GSIsGooglePhotos()?GSL(@"Language and storage display changes apply when the profile menu reopens. Unlimited storage changes the card display only, not your account limit or upload quality."):GSL(@"Choose the GoToHP display language. The profile menu updates the next time it opens.")}];
 return groups;
}
- (NSInteger)queueSection{return self.controlSections.count+1;}
- (NSInteger)controlAtPath:(NSIndexPath *)path{
 NSArray *sections=self.controlSections;
 if(path.section<1||path.section>sections.count)return -1;
 NSArray *rows=sections[path.section-1][@"rows"];
 return path.row<rows.count?[rows[path.row]integerValue]:-1;
}
- (NSString *)qualityTitle:(NSString *)quality{
 return @{@"original":GSL(@"Original quality · Pixel 1"),@"saver":GSL(@"Storage saver · Pixel 2"),@"quota":GSL(@"Original quality · Uses account storage")}[quality?:@""]?:GSL(@"Not configured");
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return self.queueSection+1;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
 if(section==0)return 1;
 if(section==self.queueSection)return MAX(self.jobs.count,1);
 return [self.controlSections[section-1][@"rows"]count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
 if(section==0)return GSL(@"Connection status");
 if(section==self.queueSection)return [NSString stringWithFormat:GSL(@"Upload history (%lu)"),(unsigned long)self.jobs.count];
 return self.controlSections[section-1][@"title"];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
 if(section==0||section==self.queueSection)return nil;
 return self.controlSections[section-1][@"footer"];
}
- (BOOL)switchValueForControl:(NSInteger)control{
 if(control==10)return GSNativeRoutingEnabled();
 if(control==11)return GSUploadDiagnosticsEnabled();
 if(control==16)return GSUnlimitedStorageEnabled();
 return [self.options[@[@"wifiOnly",@"chargingOnly",@"paused"][control-3]]boolValue];
}
- (void)controlSwitchChanged:(UISwitch *)toggle{
 NSInteger control=toggle.tag;BOOL desired=toggle.on;
 [toggle setOn:[self switchValueForControl:control] animated:YES];
 if(control==16){GSSetUnlimitedStorage(desired);[self reloadTablePreservingPosition];return;}
 if(self.busy)return;
 if(control==10){[self toggleNativeRouting];return;}
 if(control==11){GSSetUploadDiagnostics(desired);[self reloadTablePreservingPosition];return;}
 NSMutableDictionary *options=[self.options mutableCopy];if(!options)return;
 options[@[@"wifiOnly",@"chargingOnly",@"paused"][control-3]]=@(desired);
 [self request:@{@"op":@"configure",@"options":options}];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path{
 UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
 cell.textLabel.numberOfLines=0;cell.detailTextLabel.numberOfLines=0;
 cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
 cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
 cell.textLabel.adjustsFontForContentSizeCategory=YES;cell.detailTextLabel.adjustsFontForContentSizeCategory=YES;
 cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;cell.imageView.tintColor=tableView.tintColor;
 if(path.section==0){
  cell.textLabel.text=[self.accounts[@"selected"]length]?self.accounts[@"selected"]:GSL(@"Google Photos account");
  cell.detailTextLabel.text=GSLocalizedStatus(self.statusText,self.statusLanguage);cell.imageView.image=[UIImage systemImageNamed:@"person.crop.circle"];
  cell.selectionStyle=UITableViewCellSelectionStyleNone;
  if(self.busy){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];cell.accessoryView=spinner;}
  return cell;
 }
 NSInteger control=[self controlAtPath:path];
 if(control>=0){
  NSArray *titles=@[GSL(@"Quality"),GSL(@"Concurrent uploads"),GSL(@"Retry limit"),GSL(@"Wi-Fi only"),GSL(@"Charging only"),GSL(@"Pause uploads"),GSL(@"Destination account"),GSL(@"Remove account from GoToHP"),GSL(@"Retry failed uploads"),GSL(@"Clear completed history"),GS_BACKUP_TITLE,GSL(@"Upload diagnostics"),GSL(@"Export diagnostics"),GSL(@"Connect or refresh account"),GSL(@"Choose photos and videos"),GSL(@"Language"),GSL(@"Show unlimited storage")];
  NSArray *icons=@[@"photo",@"square.stack.3d.up",@"arrow.clockwise",@"wifi",@"battery.100.bolt",@"pause.circle",@"person.crop.circle.badge.checkmark",@"person.crop.circle.badge.minus",@"arrow.clockwise.circle",@"checkmark.circle",@"arrow.triangle.branch",@"waveform.path.ecg",@"square.and.arrow.up",@"person.crop.circle.badge.checkmark",@"plus.circle",@"globe",@"cloud"];
  cell.textLabel.text=titles[control];cell.imageView.image=[UIImage systemImageNamed:icons[control]];
  cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
  if(control==15)cell.detailTextLabel.text=[GSLanguageOverride()isEqual:@"system"]?GSL(@"System default"):[GSLanguageOverride()isEqual:@"ja"]?GSL(@"Japanese"):@"English";
  if(control==0)cell.detailTextLabel.text=[self qualityTitle:self.options[@"quality"]];
  if(control==1)cell.detailTextLabel.text=[NSString stringWithFormat:GSL(@"Concurrent uploads: %@"),self.options[@"concurrent"]?:@1];
  if(control==2)cell.detailTextLabel.text=[NSString stringWithFormat:GSL(@"Retry limit: %@"),self.options[GSL(@"retries")]?:@3];
  if(control==6)cell.detailTextLabel.text=self.accounts[@"selected"];
  if(control==13)cell.detailTextLabel.text=GSL(@"Check the connection for the signed-in account");
  if(control==7)cell.textLabel.textColor=UIColor.systemRedColor;
  if((control>=3&&control<=5)||control==10||control==11||control==16){
   UISwitch *toggle=[UISwitch new];toggle.tag=control;toggle.on=[self switchValueForControl:control];
   toggle.accessibilityLabel=titles[control];toggle.onTintColor=tableView.tintColor;
   toggle.enabled=control==16?GSUnlimitedStorageAvailable():!self.busy&&(control==10?GSNativeRoutingAvailable():control==11?GSUploadDiagnosticsAvailable():self.options!=nil);
   [toggle addTarget:self action:@selector(controlSwitchChanged:) forControlEvents:UIControlEventValueChanged];
   cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
  }
  if(control==16&&!GSUnlimitedStorageAvailable())cell.detailTextLabel.text=GSL(@"Unavailable in this version");
  if(control==10)cell.detailTextLabel.text=GSNativeRoutingAvailable()?GS_BACKUP_TITLE:GSL(@"Unavailable in this version");
  return cell;
 }
 if(!self.jobs.count){cell.textLabel.text=GSL(@"No uploads yet");cell.detailTextLabel.text=GSL(@"Use Choose photos and videos to add items.");cell.imageView.image=[UIImage systemImageNamed:@"tray"];cell.selectionStyle=UITableViewCellSelectionStyleNone;return cell;}
 NSDictionary *job=self.jobs[path.row];NSArray *resources=job[@"resources"];
 NSString *state=job[@"state"];NSDictionary *states=@{@"pending":GSL(@"Pending"),@"preparing":GSL(@"Preparing"),@"uploading":GSL(@"Uploading"),@"committing":GSL(@"Committing"),@"completed":GSL(@"Completed"),@"failed":GSL(@"Failed"),@"cancelled":GSL(@"Cancelled")};
 cell.textLabel.text=resources.firstObject[@"name"]?:GSL(@"Media");
 long long uploaded=[job[@"uploaded"]longLongValue],total=[job[@"total"]longLongValue];
 NSString *sizes=[NSString stringWithFormat:@"%@ / %@",[NSByteCountFormatter stringFromByteCount:uploaded countStyle:NSByteCountFormatterCountStyleFile],[NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile]];
 cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@\n%@",states[state?:@""]?:GSL(@"Checking status"),[self qualityTitle:job[@"quality"]],sizes];
 cell.imageView.image=[UIImage systemImageNamed:[state isEqual:@"completed"]?@"checkmark.circle.fill":[state isEqual:@"failed"]?@"exclamationmark.circle":@"icloud.and.arrow.up"];
 if([state isEqual:@"failed"]){cell.imageView.tintColor=UIColor.systemRedColor;cell.detailTextLabel.text=[cell.detailTextLabel.text stringByAppendingString:GSL(@"\nTap to retry")];}else if([state isEqual:@"completed"])cell.imageView.tintColor=UIColor.systemGreenColor;
 cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (void)chooseValueForControl:(NSInteger)control{
 NSString *key=@[@"quality",@"concurrent",GSL(@"retries")][control];
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@[GSL(@"Quality"),GSL(@"Concurrent uploads"),GSL(@"Retry limit")][control] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 NSArray *values=control==0?@[@"original",@"saver",@"quota"]:control==1?@[@1,@2,@3,@4]:@[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10];
 for(id value in values){
  NSString *title=control==0?[self qualityTitle:value]:[NSString stringWithFormat:@"%@ %@",value,control==1?GSL(@"uploads"):GSL(@"retries")];
  if([value isEqual:self.options[key]])title=[@"✓ " stringByAppendingString:title];
  [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSMutableDictionary *options=[self.options mutableCopy];if(!options)return;options[key]=value;[self request:@{@"op":@"configure",@"options":options}];}]];
 }
 [sheet addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];[self sheet:sheet];
}
- (void)request:(NSDictionary *)request{
 if(self.busy)return;self.stateGeneration++;self.busy=YES;[self message:GSL(@"Applying settings…")];self.navigationItem.rightBarButtonItem.enabled=NO;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;GSRequest(request,&error);dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.navigationItem.rightBarButtonItem.enabled=YES;if(error)[self message:error.localizedDescription];else[self refresh];});});
}
- (void)sheet:(UIAlertController *)sheet{sheet.popoverPresentationController.sourceView=self.view;sheet.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);[self presentViewController:sheet animated:YES completion:nil];}
- (void)primary{if(self.busy)return;if(self.settingsMode)[self addAccount];else if(self.sharedItems.count){NSArray *items=self.sharedItems;self.sharedItems=nil;if([items.firstObject isKindOfClass:PHAsset.class])[self importAssets:items];else[self importURLs:items];}else[self choose];}
#if GS_JAILED
- (void)connectNativeAccount{
 NSDictionary *account=GSNativeAccountSummary();
 if(!account){[self message:GSL(@"Could not retrieve the Google Photos account. Reopen the profile menu.")];return;}
 self.stateGeneration++;self.nativeAuthorizationFailed=NO;self.busy=YES;[self message:GSL(@"Checking the signed-in Google Photos account…")];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSError *error=nil;
  GSRequest(@{@"op":@"account_native",@"account":account[@"email"],@"nativeID":account[@"identifier"]},&error);
  dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;
   if(error){self.nativeAuthorizationFailed=YES;[self message:GSL(@"Could not obtain or validate Google Photos authorization. Check your sign-in status, then tap Reconnect.")];return;}
   [self refresh];
  });
 });
}
#endif
- (void)addAccount{
#if GS_JAILED
 if(GSIsGooglePhotos()){[self connectNativeAccount];return;}
#endif
 UIAlertController *a=[UIAlertController alertControllerWithTitle:GSL(@"Add Google account") message:GS_AUTH_HELP preferredStyle:UIAlertControllerStyleAlert];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.secureTextEntry=YES;f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.placeholder=@"oauth_token / credential";}];
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Connect") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSString *secret=a.textFields.firstObject.text;a.textFields.firstObject.text=@"";[self request:@{@"op":@"account_add",@"secret":secret?:@""}];}]];[self sheet:a];
}
- (void)exportUploadDiagnostics{
 NSMutableDictionary *snapshot=[GSUploadDiagnosticsSnapshot() mutableCopy];
 snapshot[@"manualRouting"]=GSNativeRoutingSnapshot();
 snapshot[@"unlimitedStorage"]=GSUnlimitedStorageSnapshot();
#if GS_JAILED
 snapshot[@"runtime"]=GSEmbeddedRuntimeSnapshot();
 snapshot[@"backupRouting"]=GSBackupRequestsSnapshot();
 snapshot[@"photosIntegration"]=GSPhotosIntegrationSnapshot();
#endif
 NSData *json=[NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:nil];
 NSURL *file=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gotohp-upload-diagnostics.json"]];
 if(!json||![json writeToURL:file options:NSDataWritingAtomic error:nil]){[self message:GSL(@"Could not export diagnostics.")];return;}
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[file] applicationActivities:nil];
 share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);
 [self presentViewController:share animated:YES completion:nil];
}
- (void)toggleNativeRouting{
#if GS_JAILED
 if(!GSBackupRequestsAvailable()){[self message:GSL(@"Backup requests cannot be routed in this version. Select items from the GoToHP upload screen.")];return;}
#endif
 if(!GSNativeRoutingAvailable()){[self message:GSL(@"Manual backup integration is unavailable in this version. Choose photos from Uploads.")];return;}
 if(GSNativeRoutingEnabled()){GSSetNativeRouting(NO,nil);[self reloadTablePreservingPosition];return;}
 NSString *account=self.accounts[@"selected"];
 if(!account.length){[self message:GS_ACCOUNT_HELP];return;}
 UIAlertController *a=[UIAlertController alertControllerWithTitle:GS_BACKUP_TITLE message:[NSString stringWithFormat:GSL(@"Destination: %@\n%@\nFailures and retries appear in the GoToHP queue. Uploads will not fall back to the native uploader."),account,GS_BACKUP_HELP] preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Enable") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){GSSetNativeRouting(YES,account);[self reloadTablePreservingPosition];}]];[self sheet:a];
}
- (void)accountAction:(BOOL)remove{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:remove?GSL(@"Remove account"):GSL(@"Destination account") message:remove?GSL(@"Cancel this account's unfinished jobs first."):nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSDictionary *account in self.accounts[@"accounts"]){NSString *email=account[@"email"];[a addAction:[UIAlertAction actionWithTitle:email style:remove?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":remove?@"account_remove":@"account_select",@"account":email}];}]];}
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path{
 [tableView deselectRowAtIndexPath:path animated:YES];
 NSInteger control=[self controlAtPath:path];
 if(control==12){[self exportUploadDiagnostics];return;}
 if(control==16)return;
 if(self.busy)return;
 if(control>=0){
  if(control==15){[self chooseLanguage];return;}
  if(control==14){[self choose];return;}
  if(control==13){[self addAccount];return;}
  if(control==10){[self toggleNativeRouting];return;}
  if(control==11){GSSetUploadDiagnostics(!GSUploadDiagnosticsEnabled());[self reloadTablePreservingPosition];return;}
  if(control==12){[self exportUploadDiagnostics];return;}
  if(control<3){[self chooseValueForControl:control];return;}
  if(control<6)return; // Use the visible switch; no hidden value cycling.
  if(control==6||control==7)[self accountAction:control==7];
  else [self request:@{@"op":control==8?@"retry_failed":@"clear_completed"}];
 }else if(path.section==self.queueSection&&path.row<self.jobs.count){
 NSDictionary *j=self.jobs[path.row];NSString *state=j[@"state"];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:j[@"resources"][0][@"name"] message:j[@"error"] preferredStyle:UIAlertControllerStyleActionSheet];
 if([state isEqual:@"failed"])[a addAction:[UIAlertAction actionWithTitle:GSL(@"Retry") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":@"retry",@"id":j[@"id"]}];}]];
 if(![state isEqual:@"completed"]&&![state isEqual:@"cancelled"])[a addAction:[UIAlertAction actionWithTitle:GSL(@"Cancel upload") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[self request:@{@"op":@"cancel",@"id":j[@"id"]}];}]];
 [a addAction:[UIAlertAction actionWithTitle:GSL(@"Close") style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
 }
}
- (void)choose{
 if(![self.accounts[@"selected"]length]){[self message:GS_ACCOUNT_HELP];return;}
 if(![NSBundle.mainBundle objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]){[self message:GSL(@"This app cannot request access to your photos.")];return;}
 [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status){dispatch_async(dispatch_get_main_queue(),^{
 if(status!=PHAuthorizationStatusAuthorized&&status!=PHAuthorizationStatusLimited){[self message:GSL(@"Allow access to your photo library.")];return;}
 PHPickerConfiguration *c=[[PHPickerConfiguration alloc]initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];c.selectionLimit=0;c.preferredAssetRepresentationMode=PHPickerConfigurationAssetRepresentationModeCurrent;
 PHPickerViewController *picker=[[PHPickerViewController alloc]initWithConfiguration:c];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];
 });}];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
 [picker dismissViewControllerAnimated:YES completion:^{NSMutableArray *ids=[NSMutableArray array];for(PHPickerResult *r in results)if(r.assetIdentifier)[ids addObject:r.assetIdentifier];
 PHFetchResult *found=[PHAsset fetchAssetsWithLocalIdentifiers:ids options:nil];NSMutableArray *assets=[NSMutableArray array];[found enumerateObjectsUsingBlock:^(PHAsset *a,NSUInteger i,BOOL *stop){[assets addObject:a];}];
 if(assets.count!=results.count)[self message:GSL(@"Some selected photos are not accessible. Update photo access permissions and select them again.")];else if(assets.count)[self importAssets:assets];}];
}
- (void)importAssets:(NSArray<PHAsset *> *)assets{[self importItems:assets assets:YES];}
- (void)importURLs:(NSArray<NSURL *> *)urls{[self importItems:urls assets:NO];}
- (void)importItems:(NSArray *)items assets:(BOOL)areAssets{
 if(self.busy){[self message:GSL(@"Wait for the current operation to finish, then try again.")];return;}self.stateGeneration++;self.busy=YES;
 __block BOOL expired=NO;__block UIBackgroundTaskIdentifier task=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{@synchronized(self){expired=YES;}}];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;NSUInteger queued=0;
 for(id item in items){@autoreleasepool{
 @synchronized(self){if(expired)break;}if(error)break;
 NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];if(error)break;
 NSArray *files=nil;NSDate *date=nil;BOOL scoped=NO;
 if(areAssets){PHAsset *asset=item;date=asset.creationDate;files=GSExportAsset(asset,dir,&error);}else{NSURL *url=item;scoped=[url startAccessingSecurityScopedResource];files=@[url];NSDictionary *attr=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];date=attr[NSFileModificationDate];}
 NSString *identifier=files?GSImportFiles(files,accounts[@"selected"],options[@"quality"],date,&error):nil;
 if(scoped)[item stopAccessingSecurityScopedResource];[NSFileManager.defaultManager removeItemAtURL:dir error:nil];
 if(!identifier)break;queued++;NSUInteger count=queued;
 dispatch_async(dispatch_get_main_queue(),^{[self message:[NSString stringWithFormat:GSL(@"Added %lu / %lu items. Keep the app open until preparation finishes."),(unsigned long)count,(unsigned long)items.count]];});
 }}
 dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;if(task!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:task];task=UIBackgroundTaskInvalid;}
 [self message:[NSString stringWithFormat:GSL(@"Added %lu / %lu items. %@"),(unsigned long)queued,(unsigned long)items.count,error?error.localizedDescription:(queued==items.count?GS_QUEUED_HELP:GSL(@"Preparation was interrupted. Select the remaining items again."))]];});
 });
}
@end

void GSPresent(UIViewController *host){if(!host)return;GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];[host presentViewController:nav animated:YES completion:nil];}
static UIViewController *GSTopPresenter(UIViewController *hint){
 UIViewController *host=hint;
 if(![host isKindOfClass:UIViewController.class]||!host.viewIfLoaded.window||host.isBeingDismissed){
  host=nil;
  for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
   if(scene.activationState!=UISceneActivationStateForegroundActive||![scene isKindOfClass:UIWindowScene.class])continue;
   for(UIWindow *window in ((UIWindowScene *)scene).windows)
    if(window.isKeyWindow&&window.windowLevel==UIWindowLevelNormal)host=window.rootViewController;
  }
 }
 while(host.presentedViewController&&!host.presentedViewController.isBeingDismissed)host=host.presentedViewController;
 return host;
}
void GSPresentSettings(UIViewController *hint){
 dispatch_async(dispatch_get_main_queue(),^{
  UIViewController *host=GSTopPresenter(hint);
  UIViewController *visible=[host isKindOfClass:UINavigationController.class]?((UINavigationController *)host).topViewController:host;
  if(!host||[visible isKindOfClass:GSPanel.class])return; // Repeated taps never stack settings.
  id<UIViewControllerTransitionCoordinator> transition=host.transitionCoordinator;
  if(transition&&transition.isAnimated){
   BOOL queued=[transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){GSPresentSettings(nil);}];
   if(queued)return;
  }
  GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];panel.settingsMode=YES;
  UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:panel];
  nav.modalPresentationStyle=UIModalPresentationPageSheet;
  [host presentViewController:nav animated:YES completion:nil];
 });
}
@interface GSLauncher : NSObject
+ (void)open:(UIButton *)button;
@end
@implementation GSLauncher
+ (void)open:(UIButton *)button{UIViewController *host=button.window.rootViewController;while(host.presentedViewController)host=host.presentedViewController;GSPresent(host);}
@end
static char GSLauncherKey;
void GSInstallButton(UIWindow *window){
 if(GSIsGooglePhotos())return;
 if(window.windowLevel!=UIWindowLevelNormal||!window.rootViewController||objc_getAssociatedObject(window,&GSLauncherKey))return;
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:@"GoToHP" forState:UIControlStateNormal];button.backgroundColor=UIColor.secondarySystemBackgroundColor;button.layer.cornerRadius=18;button.accessibilityLabel=GSL(@"Open the GoToHP upload queue");
 [button addTarget:GSLauncher.class action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];button.translatesAutoresizingMaskIntoConstraints=NO;[window addSubview:button];
 [NSLayoutConstraint activateConstraints:@[[button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-12],[button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-65],[button.widthAnchor constraintEqualToConstant:84],[button.heightAnchor constraintEqualToConstant:40]]];
 objc_setAssociatedObject(window,&GSLauncherKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@interface GSUploadActivity ()
@property(nonatomic,strong) NSArray *items;
@end
@implementation GSUploadActivity
- (NSString *)activityType{return @"dev.tqmane.gunshot.upload";}
- (NSString *)activityTitle{return GSL(@"Upload with GoToHP");}
- (UIImage *)activityImage{return [UIImage systemImageNamed:@"icloud.and.arrow.up"];}
- (BOOL)canPerformWithActivityItems:(NSArray *)items{if(!items.count)return NO;BOOL assets=[items.firstObject isKindOfClass:PHAsset.class];for(id i in items)if(assets?![i isKindOfClass:PHAsset.class]:!([i isKindOfClass:NSURL.class]&&[i isFileURL]))return NO;return YES;}
- (void)prepareWithActivityItems:(NSArray *)items{self.items=items;}
- (UIViewController *)activityViewController{
 GSPanel *panel=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];
 panel.sharedItems=self.items;
 __weak GSUploadActivity *weak=self;panel.activityCompletion=^{[weak activityDidFinish:YES];};
 // Use an explicit button so opening the activity does not upload automatically.
 panel.navigationItem.prompt=GSL(@"Tap Add to queue the selected items.");
 return [[UINavigationController alloc]initWithRootViewController:panel];
}
@end
