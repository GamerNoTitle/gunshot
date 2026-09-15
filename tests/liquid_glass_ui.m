#import "../UI/GSAppearance.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdlib.h>

static NSString *Documents(void){return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;}
static void Finish(BOOL success,NSString *reason){
 [[NSString stringWithFormat:@"%@ %@\n",success?@"PASS":@"FAIL",reason]writeToFile:[Documents()stringByAppendingPathComponent:@"result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 NSLog(@"Liquid Glass: %@",reason);exit(success?0:1);
}
static void Check(BOOL condition,NSString *reason){if(!condition)Finish(NO,reason);}
static NSUInteger FactoryCalls;
static id (*OriginalFactory)(id,SEL);
static id ObserveFactory(id object,SEL selector){FactoryCalls++;return OriginalFactory(object,selector);}
static id NoConfiguration(id object,SEL selector){return nil;}
static BOOL (*OriginalResponds)(id,SEL,SEL);
static BOOL MissingFactory(id object,SEL selector,SEL query){return query==NSSelectorFromString(@"glassButtonConfiguration")?NO:OriginalResponds(object,selector,query);}
static NSUInteger GlassViews(UIView *view){
 NSUInteger count=[view isKindOfClass:UIVisualEffectView.class]&&[((UIVisualEffectView *)view).effect isKindOfClass:NSClassFromString(@"UIGlassEffect")];
 for(UIView *child in view.subviews)count+=GlassViews(child);
 return count;
}
static void Capture(UIWindow *window,NSString *name){
 [window layoutIfNeeded];
 UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:window.bounds.size];
 NSData *png=[renderer PNGDataWithActions:^(UIGraphicsImageRendererContext *context){[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];}];
 [png writeToFile:[Documents()stringByAppendingPathComponent:name] atomically:YES];
}
@interface GSGlassFixtureController : UITableViewController
@property(nonatomic) NSUInteger taps;
@property(nonatomic,weak) id lastSender;
@property(nonatomic,strong) UIButton *launcher;
@end
@implementation GSGlassFixtureController
- (void)tap:(id)sender{self.taps++;self.lastSender=sender;}
- (void)alternateTap:(id)sender{self.taps+=10;self.lastSender=sender;}
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"GoToHP";
 self.navigationItem.leftBarButtonItem=GSNavigationButton(@"完了",self,@selector(tap:));
 self.navigationItem.rightBarButtonItems=@[GSNavigationButton(@"再接続",self,@selector(tap:)),GSNavigationButton(@"アップロード",self,@selector(tap:))];
 self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;
 self.launcher=[UIButton buttonWithType:UIButtonTypeSystem];[self.launcher setTitle:@"GoToHP" forState:UIControlStateNormal];
 if(!GSApplyGlassButton(self.launcher)){self.launcher.backgroundColor=UIColor.secondarySystemBackgroundColor;self.launcher.layer.cornerRadius=18;}
 self.launcher.accessibilityLabel=@"Open the GoToHP upload queue";
 [self.launcher addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
 UIView *header=[[UIView alloc]initWithFrame:CGRectMake(0,0,320,80)];self.launcher.frame=CGRectMake(20,16,110,44);[header addSubview:self.launcher];self.tableView.tableHeaderView=header;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return 30;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path{
 UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
 cell.textLabel.text=path.row%2?@"Upload settings":@"Connection status";
 cell.detailTextLabel.text=@"Content stays readable; glass is reserved for controls.";cell.detailTextLabel.numberOfLines=0;
 return cell;
}
- (void)checkControls{
 BOOL modern=NO;if(@available(iOS 26.0,*))modern=YES;
 NSArray *items=@[self.navigationItem.leftBarButtonItem,self.navigationItem.rightBarButtonItems[0],self.navigationItem.rightBarButtonItems[1]];
 Check((modern?FactoryCalls>=4:FactoryCalls==0),@"OS gate must use the real public factory only on iOS 26+");
 for(UIBarButtonItem *item in items){
  Check(item.target==self&&item.action==@selector(tap:),@"target/action changed");
  Check((item.customView!=nil)==modern,@"wrong legacy/glass branch");
  if(!modern)continue;
  UIButton *button=(UIButton *)item.customView;
  Check([button isKindOfClass:UIButton.class]&&button.configuration!=nil,@"glass configuration absent");
  Check([[button titleForState:UIControlStateNormal]isEqual:item.title],@"initial localized title lost");
  Check(button.titleLabel.adjustsFontForContentSizeCategory,@"Dynamic Type disabled");
  SEL hides=NSSelectorFromString(@"hidesSharedBackground");
  Check([item respondsToSelector:hides]&&((BOOL(*)(id,SEL))objc_msgSend)(item,hides),@"bar would draw a second glass background");
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];
  Check(self.lastSender==item,@"custom button did not preserve bar item sender");
  NSUInteger before=self.taps;item.enabled=NO;
  Check(!button.enabled,@"disabled bar item left custom button enabled");
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];Check(self.taps==before,@"disabled action was delivered");
  item.enabled=YES;Check(button.enabled,@"re-enabled state not forwarded");
 }
 if(modern){
  UIBarButtonItem *item=items[0];UIButton *button=(UIButton *)item.customView;
  item.action=@selector(alternateTap:);NSUInteger before=self.taps;
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];Check(self.taps==before+10,@"changed action was not respected");item.action=@selector(tap:);
  GSGlassFixtureController *other=[GSGlassFixtureController new];item.target=other;
  [button sendActionsForControlEvents:UIControlEventTouchUpInside];Check(other.taps==1&&other.lastSender==item,@"changed target was not respected");item.target=self;
  __weak UIBarButtonItem *released;
  @autoreleasepool{released=GSNavigationButton(@"Temporary",self,@selector(tap:));}
  Check(released==nil,@"bar item/button retain cycle");
  // Missing API and unexpected nil configuration must leave the old UI intact.
  Class meta=object_getClass(UIButtonConfiguration.class);SEL factory=NSSelectorFromString(@"glassButtonConfiguration");
  SEL responds=@selector(respondsToSelector:);Method responseMethod=class_getClassMethod(UIButtonConfiguration.class,responds);
  OriginalResponds=(void *)method_getImplementation(responseMethod);
  class_replaceMethod(meta,responds,(IMP)MissingFactory,method_getTypeEncoding(responseMethod));
  Check(GSNavigationButton(@"Missing",self,@selector(tap:)).customView==nil,@"missing API did not fall back");
  class_replaceMethod(meta,responds,(IMP)OriginalResponds,method_getTypeEncoding(responseMethod));
  Method method=class_getClassMethod(UIButtonConfiguration.class,factory);IMP observed=method_setImplementation(method,(IMP)NoConfiguration);
  UIButton *plain=[UIButton buttonWithType:UIButtonTypeSystem];plain.backgroundColor=UIColor.systemRedColor;
  Check(!GSApplyGlassButton(plain)&&plain.configuration==nil&&[plain.backgroundColor isEqual:UIColor.systemRedColor],@"fallback mutated the old button");
  Check(GSNavigationButton(@"Nil",self,@selector(tap:)).customView==nil,@"nil API result did not fall back");
  method_setImplementation(method,observed);
 }
 UIBarButtonItem *host=[[UIBarButtonItem alloc]initWithTitle:@"Unmodified host" style:UIBarButtonItemStylePlain target:self action:@selector(tap:)];
 Check(host.customView==nil,@"ordinary host bar item was modified");
}
@end
@interface GSGlassFixtureScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic) BOOL started;
@end
@implementation GSGlassFixtureScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];
 GSGlassFixtureController *controller=[[GSGlassFixtureController alloc]initWithStyle:UITableViewStyleInsetGrouped];
 self.window.rootViewController=[[UINavigationController alloc]initWithRootViewController:controller];[self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene{
 if(self.started)return;self.started=YES;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  UINavigationController *nav=(UINavigationController *)self.window.rootViewController;
  GSGlassFixtureController *controller=(GSGlassFixtureController *)nav.topViewController;[controller checkControls];
  Capture(self.window,@"glass-japanese-light.png");
  NSArray *items=@[controller.navigationItem.leftBarButtonItem,controller.navigationItem.rightBarButtonItems[0],controller.navigationItem.rightBarButtonItems[1]];
  NSArray *titles=@[@"Done",@"Reconnect",@"Uploads"];
  for(NSUInteger i=0;i<items.count;i++){
   UIBarButtonItem *item=items[i];item.title=titles[i];
   if(item.customView)Check([[(UIButton *)item.customView titleForState:UIControlStateNormal]isEqual:titles[i]],@"language change did not update visible button");
  }
  self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
   Capture(self.window,@"glass-english-dark.png");
   Check([controller.launcher.accessibilityLabel isEqual:@"Open the GoToHP upload queue"],@"launcher accessibility label lost");
   [controller.launcher sendActionsForControlEvents:UIControlEventTouchUpInside];Check(controller.lastSender==controller.launcher,@"launcher action changed");
   NSLog(@"Public UIGlassEffect views in rendered hierarchy: %lu",(unsigned long)GlassViews(self.window));
   Finish(YES,[NSString stringWithFormat:@"iOS %@; factory calls %lu; localized controls, action forwarding, disabled state, fallback and host isolation",NSProcessInfo.processInfo.operatingSystemVersionString,(unsigned long)FactoryCalls]);
  });
 });
}
@end
@interface GSGlassFixtureApp : UIResponder <UIApplicationDelegate> @end
@implementation GSGlassFixtureApp
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{
 UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:@"Glass fixture" sessionRole:session.role];config.delegateClass=GSGlassFixtureScene.class;return config;
}
@end
int main(int argc,char **argv){@autoreleasepool{
 if(@available(iOS 26.0,*)){
  Method method=class_getClassMethod(UIButtonConfiguration.class,NSSelectorFromString(@"glassButtonConfiguration"));
  Check(method!=NULL,@"iOS 26 simulator lacks the public glass factory");OriginalFactory=(void *)method_setImplementation(method,(IMP)ObserveFactory);
 }
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,45*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{Finish(NO,@"fixture watchdog");});
 return UIApplicationMain(argc,argv,nil,NSStringFromClass(GSGlassFixtureApp.class));
}}
