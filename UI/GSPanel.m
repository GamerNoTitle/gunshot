#import "GSPanel.h"
#import "GSExporter.h"
#import "GSNativeAccount.h"
#import "GSNativeRouting.h"
#import "GSUploadDiagnostics.h"
#import "../Shared/IPCProtocol.h"
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>
#if GS_JAILED
#define GS_ACCOUNT_HELP @"アカウントの接続・更新を実行してください。"
#define GS_QUEUED_HELP @"アップロード中はこのアプリを開いてください。待機中の項目は次回起動時に再開します。"
#define GS_AUTH_HELP @"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. It is stored privately in this app and sent to Google. It is never displayed again."
#else
#define GS_ACCOUNT_HELP @"設定 → GoToHP からアカウントを追加してください。"
#define GS_QUEUED_HELP @"アプリを閉じてもバックグラウンドでアップロードを続けます。"
#define GS_AUTH_HELP @"Paste the EmbeddedSetup oauth_token or a complete gotohp credential. The value is sent only to gotohpd and Google. It is never displayed again."
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
@property(nonatomic,strong) NSArray *routedAssets;
@property(nonatomic,copy) NSString *routeAccount;
@property(nonatomic,copy) void (^activityCompletion)(void);
@property(nonatomic,copy) NSString *statusText;
@end
@implementation GSPanel
- (void)viewDidLoad{
 [super viewDidLoad];GSInstallNativeRouting();GSInstallUploadDiagnostics();self.title=@"GoToHP";self.jobs=@[];self.statusText=@"接続を確認しています…";
 self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:self.settingsMode?@"再接続":@"追加" style:UIBarButtonItemStylePlain target:self action:@selector(primary)];
#if !GS_JAILED
 if(self.settingsMode)self.navigationItem.rightBarButtonItem.title=@"アカウント";
#endif
#if GS_JAILED
 self.navigationItem.prompt=nil;
#endif
 if(self.settingsMode&&GSIsGooglePhotos()){
 UIBarButtonItem *upload=[[UIBarButtonItem alloc]initWithTitle:@"アップロード" style:UIBarButtonItemStylePlain target:self action:@selector(openUploadPanel)];
 self.navigationItem.rightBarButtonItems=@[self.navigationItem.rightBarButtonItem,upload];
 }
 if(!self.settingsMode&&GSIsGooglePhotos()){
 UIBarButtonItem *settings=[[UIBarButtonItem alloc]initWithTitle:@"設定" style:UIBarButtonItemStylePlain target:self action:@selector(openEmbeddedSettings)];
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
- (void)message:(NSString *)message{self.statusText=message;[self.tableView reloadData];}
- (void)refresh{
 if(self.busy||self.refreshing||self.nativeAuthorizationFailed)return;self.refreshing=YES;
 NSUInteger generation=self.stateGeneration;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;
 NSMutableArray *jobs=[NSMutableArray array];NSInteger cursor=0;NSDictionary *page=nil;
 if(options)do{page=GSRequest(@{@"op":@"list",@"cursor":@(cursor)},&error);if(!page)break;[jobs addObjectsFromArray:page[@"jobs"]?:@[]];cursor=[page[@"next"]integerValue];}while(cursor>=0);
 dispatch_async(dispatch_get_main_queue(),^{self.refreshing=NO;if(generation!=self.stateGeneration){[self refresh];return;}if(error){[self message:error.localizedDescription];return;}self.accounts=accounts;self.options=[options mutableCopy];self.jobs=jobs;
 self.statusText=[accounts[@"selected"]length]?([page[@"online"]boolValue]?@"接続済み":@"ネットワーク接続を待っています"):@"アカウントの接続が必要です";
 [self.tableView reloadData];
 if(self.routedAssets){NSArray *assets=self.routedAssets;self.routedAssets=nil;
 if(!assets.count){[self message:@"選択した写真を取得できませんでした。「アップロード」から選び直してください。バックアップは開始していません。"];return;}
 if(![self.routeAccount isEqualToString:accounts[@"selected"]]){[self message:@"送信先が変更されました。設定で手動バックアップ連携を有効にし直してください。バックアップは開始していません。"];return;}
 [self importAssets:assets];
 }
 });
 });
}
- (NSArray<NSDictionary *> *)controlSections{
 if(!self.settingsMode)return @[@{@"title":@"アップロード",@"rows":@[@14],@"footer":GS_QUEUED_HELP}];
 NSMutableArray *groups=[NSMutableArray array];
 NSArray *accountRows=@[@13,@6,@7];
#if GS_JAILED
 if(GSIsGooglePhotos())accountRows=@[@13];
#endif
 [groups addObject:@{@"title":@"アカウント",@"rows":accountRows,@"footer":@"接続状態と送信先を上で確認できます。"}];
 [groups addObject:@{@"title":@"アップロード設定",@"rows":@[@0,@1,@2,@3,@4,@5],@"footer":GS_QUEUED_HELP}];
 if(GSIsGooglePhotos())[groups addObject:@{@"title":@"Google Photos との連携",@"rows":@[@10],@"footer":@"手動の「今すぐバックアップ」が対象です。自動バックアップの置き換えは未対応です。"}];
 [groups addObject:@{@"title":@"キューの管理",@"rows":@[@8,@9]}];
 if(GSIsGooglePhotos())[groups addObject:@{@"title":@"診断",@"rows":@[@11,@12],@"footer":@"互換性調査用です。トークンやメディア本体は記録しません。"}];
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
 return @{@"original":@"オリジナル画質",@"saver":@"容量を節約",@"quota":@"通常の保存容量を使用"}[quality?:@""]?:@"未設定";
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return self.queueSection+1;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
 if(section==0)return 1;
 if(section==self.queueSection)return MAX(self.jobs.count,1);
 return [self.controlSections[section-1][@"rows"]count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
 if(section==0)return @"接続状態";
 if(section==self.queueSection)return [NSString stringWithFormat:@"アップロード履歴（%lu件）",(unsigned long)self.jobs.count];
 return self.controlSections[section-1][@"title"];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
 if(section==0||section==self.queueSection)return nil;
 return self.controlSections[section-1][@"footer"];
}
- (BOOL)switchValueForControl:(NSInteger)control{
 if(control==10)return GSNativeRoutingEnabled();
 if(control==11)return GSUploadDiagnosticsEnabled();
 return [self.options[@[@"wifiOnly",@"chargingOnly",@"paused"][control-3]]boolValue];
}
- (void)controlSwitchChanged:(UISwitch *)toggle{
 NSInteger control=toggle.tag;BOOL desired=toggle.on;
 [toggle setOn:[self switchValueForControl:control] animated:YES];
 if(self.busy)return;
 if(control==10){[self toggleNativeRouting];return;}
 if(control==11){GSSetUploadDiagnostics(desired);[self.tableView reloadData];return;}
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
  cell.textLabel.text=[self.accounts[@"selected"]length]?self.accounts[@"selected"]:@"Google Photos アカウント";
  cell.detailTextLabel.text=self.statusText;cell.imageView.image=[UIImage systemImageNamed:@"person.crop.circle"];
  cell.selectionStyle=UITableViewCellSelectionStyleNone;
  if(self.busy){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];[spinner startAnimating];cell.accessoryView=spinner;}
  return cell;
 }
 NSInteger control=[self controlAtPath:path];
 if(control>=0){
  NSArray *titles=@[@"画質",@"同時アップロード数",@"再試行回数",@"Wi-Fi 接続時のみ",@"充電中のみ",@"アップロードを一時停止",@"送信先アカウント",@"GoToHP からアカウントを削除",@"失敗した項目を再試行",@"完了した履歴を消去",@"手動バックアップを GoToHP へ送る",@"アップロードの診断",@"診断データを書き出す",@"アカウントを接続・更新",@"写真・動画を選択"];
  NSArray *icons=@[@"photo",@"square.stack.3d.up",@"arrow.clockwise",@"wifi",@"battery.100.bolt",@"pause.circle",@"person.crop.circle.badge.checkmark",@"person.crop.circle.badge.minus",@"arrow.clockwise.circle",@"checkmark.circle",@"arrow.triangle.branch",@"waveform.path.ecg",@"square.and.arrow.up",@"person.crop.circle.badge.checkmark",@"plus.circle"];
  cell.textLabel.text=titles[control];cell.imageView.image=[UIImage systemImageNamed:icons[control]];
  cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
  if(control==0)cell.detailTextLabel.text=[self qualityTitle:self.options[@"quality"]];
  if(control==1)cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ 件",self.options[@"concurrent"]?:@1];
  if(control==2)cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ 回",self.options[@"retries"]?:@3];
  if(control==6)cell.detailTextLabel.text=self.accounts[@"selected"];
  if(control==13)cell.detailTextLabel.text=@"ログイン中のアカウントの接続を確認します";
  if(control==7)cell.textLabel.textColor=UIColor.systemRedColor;
  if((control>=3&&control<=5)||control==10||control==11){
   UISwitch *toggle=[UISwitch new];toggle.tag=control;toggle.on=[self switchValueForControl:control];
   toggle.accessibilityLabel=titles[control];toggle.onTintColor=tableView.tintColor;
   toggle.enabled=!self.busy&&(control==10?GSNativeRoutingAvailable():control==11?GSUploadDiagnosticsAvailable():self.options!=nil);
   [toggle addTarget:self action:@selector(controlSwitchChanged:) forControlEvents:UIControlEventValueChanged];
   cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
  }
  if(control==10)cell.detailTextLabel.text=GSNativeRoutingAvailable()?@"「今すぐバックアップ」の手動操作に適用":@"このバージョンでは利用できません";
  return cell;
 }
 if(!self.jobs.count){cell.textLabel.text=@"まだアップロードはありません";cell.detailTextLabel.text=@"「写真・動画を選択」から追加できます。";cell.imageView.image=[UIImage systemImageNamed:@"tray"];cell.selectionStyle=UITableViewCellSelectionStyleNone;return cell;}
 NSDictionary *job=self.jobs[path.row];NSArray *resources=job[@"resources"];
 NSString *state=job[@"state"];NSDictionary *states=@{@"pending":@"待機中",@"preparing":@"準備中",@"uploading":@"アップロード中",@"committing":@"保存を確定中",@"completed":@"完了",@"failed":@"失敗",@"cancelled":@"キャンセル済み"};
 cell.textLabel.text=resources.firstObject[@"name"]?:@"メディア";
 long long uploaded=[job[@"uploaded"]longLongValue],total=[job[@"total"]longLongValue];
 NSString *sizes=[NSString stringWithFormat:@"%@ / %@",[NSByteCountFormatter stringFromByteCount:uploaded countStyle:NSByteCountFormatterCountStyleFile],[NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile]];
 cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@\n%@",states[state?:@""]?:@"状態を確認中",[self qualityTitle:job[@"quality"]],sizes];
 cell.imageView.image=[UIImage systemImageNamed:[state isEqual:@"completed"]?@"checkmark.circle.fill":[state isEqual:@"failed"]?@"exclamationmark.circle":@"icloud.and.arrow.up"];
 if([state isEqual:@"failed"]){cell.imageView.tintColor=UIColor.systemRedColor;cell.detailTextLabel.text=[cell.detailTextLabel.text stringByAppendingString:@"\nタップして再試行できます"];}else if([state isEqual:@"completed"])cell.imageView.tintColor=UIColor.systemGreenColor;
 cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (void)chooseValueForControl:(NSInteger)control{
 NSString *key=@[@"quality",@"concurrent",@"retries"][control];
 UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@[@"画質",@"同時アップロード数",@"再試行回数"][control] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 NSArray *values=control==0?@[@"original",@"saver",@"quota"]:control==1?@[@1,@2,@3,@4]:@[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10];
 for(id value in values){
  NSString *title=control==0?[self qualityTitle:value]:[NSString stringWithFormat:@"%@ %@",value,control==1?@"件":@"回"];
  if([value isEqual:self.options[key]])title=[@"✓ " stringByAppendingString:title];
  [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSMutableDictionary *options=[self.options mutableCopy];if(!options)return;options[key]=value;[self request:@{@"op":@"configure",@"options":options}];}]];
 }
 [sheet addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];[self sheet:sheet];
}
- (void)request:(NSDictionary *)request{
 if(self.busy)return;self.stateGeneration++;self.busy=YES;[self message:@"設定を反映しています…"];self.navigationItem.rightBarButtonItem.enabled=NO;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSError *error=nil;GSRequest(request,&error);dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.navigationItem.rightBarButtonItem.enabled=YES;if(error)[self message:error.localizedDescription];else[self refresh];});});
}
- (void)sheet:(UIAlertController *)sheet{sheet.popoverPresentationController.sourceView=self.view;sheet.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);[self presentViewController:sheet animated:YES completion:nil];}
- (void)primary{if(self.busy)return;if(self.settingsMode)[self addAccount];else if(self.sharedItems.count){NSArray *items=self.sharedItems;self.sharedItems=nil;if([items.firstObject isKindOfClass:PHAsset.class])[self importAssets:items];else[self importURLs:items];}else[self choose];}
#if GS_JAILED
- (void)connectNativeAccount{
 NSDictionary *account=GSNativeAccountSummary();
 if(!account){[self message:@"Google Photos のアカウントを取得できません。プロフィールメニューを開き直してください。"];return;}
 self.stateGeneration++;self.nativeAuthorizationFailed=NO;self.busy=YES;[self message:@"Google Photos のログイン中アカウントを確認中…"];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSError *error=nil;
  GSRequest(@{@"op":@"account_native",@"account":account[@"email"],@"nativeID":account[@"identifier"]},&error);
  dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;
   if(error){self.nativeAuthorizationFailed=YES;[self message:@"Google Photos の認証を取得・検証できませんでした。ログイン状態を確認して「再接続」から再試行してください。"];return;}
   [self refresh];
  });
 });
}
#endif
- (void)addAccount{
#if GS_JAILED
 if(GSIsGooglePhotos()){[self connectNativeAccount];return;}
#endif
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Google アカウントを追加" message:GS_AUTH_HELP preferredStyle:UIAlertControllerStyleAlert];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.secureTextEntry=YES;f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.placeholder=@"oauth_token / credential";}];
 [a addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:@"接続" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSString *secret=a.textFields.firstObject.text;a.textFields.firstObject.text=@"";[self request:@{@"op":@"account_add",@"secret":secret?:@""}];}]];[self sheet:a];
}
- (void)exportUploadDiagnostics{
 NSData *json=[NSJSONSerialization dataWithJSONObject:GSUploadDiagnosticsSnapshot() options:NSJSONWritingPrettyPrinted error:nil];
 NSURL *file=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"gotohp-upload-diagnostics.json"]];
 if(!json||![json writeToURL:file options:NSDataWritingAtomic error:nil]){[self message:@"診断データを書き出せませんでした。"];return;}
 UIActivityViewController *share=[[UIActivityViewController alloc]initWithActivityItems:@[file] applicationActivities:nil];
 share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,80,1,1);
 [self presentViewController:share animated:YES completion:nil];
}
- (void)toggleNativeRouting{
 if(!GSNativeRoutingAvailable()){[self message:@"このバージョンでは手動バックアップ連携を利用できません。「アップロード」から写真を選択してください。"];return;}
 if(GSNativeRoutingEnabled()){GSSetNativeRouting(NO,nil);[self.tableView reloadData];return;}
 NSString *account=self.accounts[@"selected"];
 if(!account.length){[self message:GS_ACCOUNT_HELP];return;}
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"手動バックアップを GoToHP に送りますか？" message:[NSString stringWithFormat:@"送信先: %@\n手動の「今すぐバックアップ」を GoToHP に送ります。自動バックアップ・共有・ロックされたフォルダは対象外です。重複を避けるには Google Photos の自動バックアップをオフにしてください。進捗は GoToHP に表示します。",account] preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];
 [a addAction:[UIAlertAction actionWithTitle:@"有効にする" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){GSSetNativeRouting(YES,account);[self.tableView reloadData];}]];[self sheet:a];
}
- (void)accountAction:(BOOL)remove{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:remove?@"アカウントを削除":@"送信先アカウント" message:remove?@"このアカウントの未完了ジョブを先にキャンセルしてください。":nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSDictionary *account in self.accounts[@"accounts"]){NSString *email=account[@"email"];[a addAction:[UIAlertAction actionWithTitle:email style:remove?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":remove?@"account_remove":@"account_select",@"account":email}];}]];}
 [a addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path{
 [tableView deselectRowAtIndexPath:path animated:YES];if(self.busy)return;
 NSInteger control=[self controlAtPath:path];
 if(control>=0){
  if(control==14){[self choose];return;}
  if(control==13){[self addAccount];return;}
  if(control==10){[self toggleNativeRouting];return;}
  if(control==11){GSSetUploadDiagnostics(!GSUploadDiagnosticsEnabled());[self.tableView reloadData];return;}
  if(control==12){[self exportUploadDiagnostics];return;}
  if(control<3){[self chooseValueForControl:control];return;}
  if(control<6)return; // Use the visible switch; no hidden value cycling.
  if(control==6||control==7)[self accountAction:control==7];
  else [self request:@{@"op":control==8?@"retry_failed":@"clear_completed"}];
 }else if(path.section==self.queueSection&&path.row<self.jobs.count){
 NSDictionary *j=self.jobs[path.row];NSString *state=j[@"state"];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:j[@"resources"][0][@"name"] message:j[@"error"] preferredStyle:UIAlertControllerStyleActionSheet];
 if([state isEqual:@"failed"])[a addAction:[UIAlertAction actionWithTitle:@"再試行" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self request:@{@"op":@"retry",@"id":j[@"id"]}];}]];
 if(![state isEqual:@"completed"]&&![state isEqual:@"cancelled"])[a addAction:[UIAlertAction actionWithTitle:@"アップロードをキャンセル" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[self request:@{@"op":@"cancel",@"id":j[@"id"]}];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"閉じる" style:UIAlertActionStyleCancel handler:nil]];[self sheet:a];
 }
}
- (void)choose{
 if(![self.accounts[@"selected"]length]){[self message:GS_ACCOUNT_HELP];return;}
 if(![NSBundle.mainBundle objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]){[self message:@"このアプリでは写真へのアクセス権限を要求できません。"];return;}
 [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status){dispatch_async(dispatch_get_main_queue(),^{
 if(status!=PHAuthorizationStatusAuthorized&&status!=PHAuthorizationStatusLimited){[self message:@"写真ライブラリへのアクセスを許可してください。"];return;}
 PHPickerConfiguration *c=[[PHPickerConfiguration alloc]initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];c.selectionLimit=0;c.preferredAssetRepresentationMode=PHPickerConfigurationAssetRepresentationModeCurrent;
 PHPickerViewController *picker=[[PHPickerViewController alloc]initWithConfiguration:c];picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];
 });}];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
 [picker dismissViewControllerAnimated:YES completion:^{NSMutableArray *ids=[NSMutableArray array];for(PHPickerResult *r in results)if(r.assetIdentifier)[ids addObject:r.assetIdentifier];
 PHFetchResult *found=[PHAsset fetchAssetsWithLocalIdentifiers:ids options:nil];NSMutableArray *assets=[NSMutableArray array];[found enumerateObjectsUsingBlock:^(PHAsset *a,NSUInteger i,BOOL *stop){[assets addObject:a];}];
 if(assets.count!=results.count)[self message:@"アクセスが許可されていない写真が含まれています。写真へのアクセス範囲を変更して選び直してください。"];else if(assets.count)[self importAssets:assets];}];
}
- (void)importAssets:(NSArray<PHAsset *> *)assets{[self importItems:assets assets:YES];}
- (void)importURLs:(NSArray<NSURL *> *)urls{[self importItems:urls assets:NO];}
- (void)importItems:(NSArray *)items assets:(BOOL)areAssets{
 if(self.busy){[self message:@"処理が完了してから再試行してください。"];return;}self.stateGeneration++;self.busy=YES;
 __block BOOL expired=NO;__block UIBackgroundTaskIdentifier task=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{@synchronized(self){expired=YES;}}];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
 NSError *error=nil;NSDictionary *accounts=GSRequest(@{@"op":@"accounts"},&error);NSDictionary *options=accounts?GSRequest(@{@"op":@"options"},&error):nil;NSUInteger queued=0;
 if(self.routeAccount&&![self.routeAccount isEqualToString:accounts[@"selected"]])error=[NSError errorWithDomain:@"Gunshot" code:1 userInfo:@{NSLocalizedDescriptionKey:@"送信先が変更されました。設定で手動バックアップ連携を有効にし直してください。"}];
 for(id item in items){@autoreleasepool{
 @synchronized(self){if(expired)break;}if(error)break;
 NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
 [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];if(error)break;
 NSArray *files=nil;NSDate *date=nil;BOOL scoped=NO;
 if(areAssets){PHAsset *asset=item;date=asset.creationDate;files=GSExportAsset(asset,dir,&error);}else{NSURL *url=item;scoped=[url startAccessingSecurityScopedResource];files=@[url];NSDictionary *attr=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];date=attr[NSFileModificationDate];}
 NSString *identifier=files?GSImportFiles(files,accounts[@"selected"],options[@"quality"],date,&error):nil;
 if(scoped)[item stopAccessingSecurityScopedResource];[NSFileManager.defaultManager removeItemAtURL:dir error:nil];
 if(!identifier)break;queued++;NSUInteger count=queued;
 dispatch_async(dispatch_get_main_queue(),^{[self message:[NSString stringWithFormat:@"%lu / %lu 件を追加しました。準備が終わるまでアプリを開いてください。",(unsigned long)count,(unsigned long)items.count]];});
 }}
 dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;if(task!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:task];task=UIBackgroundTaskInvalid;}
 [self message:[NSString stringWithFormat:@"%lu / %lu 件を追加しました。%@",(unsigned long)queued,(unsigned long)items.count,error?error.localizedDescription:(queued==items.count?GS_QUEUED_HELP:@"準備を中断しました。残りの項目を選び直してください。")]];});
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
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];[button setTitle:@"GoToHP" forState:UIControlStateNormal];button.backgroundColor=UIColor.secondarySystemBackgroundColor;button.layer.cornerRadius=18;button.accessibilityLabel=@"GoToHP のアップロードキューを開く";
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
 panel.navigationItem.prompt=@"「追加」をタップして選択した項目をキューに入れます。";
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
