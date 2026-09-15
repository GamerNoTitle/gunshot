#import "GSPhotosGlass.h"
#import "../Shared/GSPhotosCompatibility.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const GSPhotosGlassPreference=@"GSPhotosBottomBarLiquidGlass";
static NSString *const GSDesignCompatibilityOverride=@"com.apple.SwiftUI.IgnoreSolariumOptOut";
static char GSGlassPairKey;
static BOOL GSInstalled,GSBootGlassEnabled,GSRestartRequired,GSDesignOverrideApplied;
static NSHashTable *GSControllers,*GSPairs;
static NSString *GSLastSkip;

// Google Photos keeps owning the real segmented control and search button. The
// visible controls are UIKit-native proxies, while the real Google controls stay
// in place as the navigation/action backend.
@interface GSPhotosGlassPair : NSObject <UITabBarControllerDelegate>
@property(nonatomic,weak) UIViewController *controller;
@property(nonatomic,weak) UIStackView *bar;
@property(nonatomic,weak) UIView *host;
@property(nonatomic,weak) UIControl *segments;
@property(nonatomic,weak) UIButton *search;
@property(nonatomic,strong) UITabBarController *nativeTabController;
@property(nonatomic,strong) UITabBar *nativeTabBar;
@property(nonatomic,strong) UIButton *searchProxy;
@property(nonatomic) CGFloat segmentsAlpha,searchAlpha;
@property(nonatomic) BOOL segmentsInteraction,searchInteraction;
@property(nonatomic) BOOL segmentsAccessibilityHidden,searchAccessibilityHidden,changing;
- (void)searchPressed:(UIButton *)sender;
@end

static id GSGet(id object,NSString *name){
 if(!object||!GSPhotosHasMethod(object_getClass(object),name,"@16@0:8"))return nil;
 return ((id(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name));
}
static NSInteger GSInteger(id object,NSString *name){return ((NSInteger(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name));}
static void GSSetInteger(id object,NSString *name,NSInteger value){((void(*)(id,SEL,NSInteger))objc_msgSend)(object,NSSelectorFromString(name),value);}
BOOL GSPhotosGlassEnabled(void){return [NSUserDefaults.standardUserDefaults boolForKey:GSPhotosGlassPreference];}

static BOOL GSPhotosGlassHostVersionSupported(void){
 if(!GSPhotosHostSupported())return NO;
 id version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
 if(![version isKindOfClass:NSString.class]||
    [version rangeOfString:@"^[0-9]+\\.[0-9]+(?:\\.[0-9]+)?$" options:NSRegularExpressionSearch].location==NSNotFound)return NO;
 return [version compare:@"7.92" options:NSNumericSearch]!=NSOrderedAscending;
}

static void GSWriteDesignCompatibilityOverride(BOOL enabled){
 if(!GSPhotosHostSupported())return;
 if(@available(iOS 26.0,*)){
  NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
  if(enabled&&GSPhotosGlassHostVersionSupported())[defaults setBool:YES forKey:GSDesignCompatibilityOverride];
  else [defaults removeObjectForKey:GSDesignCompatibilityOverride];
  [defaults synchronize];
 }
}

static BOOL GSPhotosGlassActiveThisLaunch(void){return GSPhotosGlassEnabled()&&!GSRestartRequired&&GSDesignOverrideApplied;}

static NSString *GSUnavailableReason(void){
 if(@available(iOS 26.0,*)){
  if(!GSPhotosHostSupported())return @"unsupported_host";
  id version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if(![version isKindOfClass:NSString.class]||
     [version rangeOfString:@"^[0-9]+\\.[0-9]+(?:\\.[0-9]+)?$" options:NSRegularExpressionSearch].location==NSNotFound)return @"unknown_version";
  if(!GSPhotosGlassHostVersionSupported())return @"requires_photos_7_92";
  // Keep the full audited 7.92.0 surface as a conservative gate for newer
  // Photos builds even though the proxy renderer only calls a subset directly.
  for(NSArray *entry in @[
   @[@"PHSTabBarController",@"viewDidLayoutSubviews",@"v16@0:8"],
   @[@"PHSTabBarController",@"floatingBottomTabBar",@"@16@0:8"],
   @[@"PHSTabBarController",@"floatingSegmentedControl",@"@16@0:8"],
   @[@"PHSTabBarController",@"floatingSearchButton",@"@16@0:8"],
   @[@"PHSSegmentedControl",@"layoutSubviews",@"v16@0:8"],
   @[@"PHSSegmentedControl",@"traitCollectionDidChange:",@"v24@0:8@16"],
   @[@"PHSSegmentedControl",@"numberOfSegments",@"q16@0:8"],
   @[@"PHSSegmentedControl",@"selectedSegmentIndex",@"q16@0:8"],
   @[@"PHSSegmentedControl",@"setSelectedSegmentIndex:",@"v24@0:8q16"],
   @[@"PHSShadowView",@"mdc_currentElevation",@"d16@0:8"],
   @[@"PHSShadowView",@"setElevation:",@"v24@0:8d16"],
   @[@"PHSShadowView",@"adaptiveBackgroundColorEnabled",@"B16@0:8"],
   @[@"PHSShadowView",@"setAdaptiveBackgroundColorEnabled:",@"v20@0:8B16"],
   @[@"M3CButton",@"layoutSubviews",@"v16@0:8"],
   @[@"M3CButton",@"phs_brandIconTonalRound",@"v16@0:8"],
   @[@"M3CButton",@"phs_brandIconTonalGlassRound",@"v16@0:8"],
   @[@"M3CButton",@"glassType",@"q16@0:8"],
   @[@"M3CButton",@"isGlassEnabled",@"B16@0:8"],
   @[@"M3CButton",@"glassEffectView",@"@16@0:8"],
   @[@"M3CButton",@"backgroundColorForState:",@"@24@0:8Q16"],
   @[@"M3CButton",@"shadowForState:",@"@24@0:8Q16"],
   @[@"M3CButton",@"tintColorForState:",@"@24@0:8Q16"],
   @[@"M3CButton",@"setBackgroundColor:forState:",@"v32@0:8@16Q24"],
   @[@"M3CButton",@"setShadow:forState:",@"v32@0:8@16Q24"],
   @[@"M3CButton",@"setTintColor:forState:",@"v32@0:8@16Q24"],
   @[@"M3CMaterialGlassEffectView",@"isGlass",@"B16@0:8"],
   @[@"M3CMaterialGlassEffectView",@"glass",@"@16@0:8"],
   @[@"M3CMaterialGlassEffectView",@"updateGlassEffect",@"v16@0:8"],
   @[@"M3CMaterialGlassEffect",@"type",@"q16@0:8"]])
   if(!GSPhotosHasMethod(NSClassFromString(entry[0]),entry[1],[entry[2]UTF8String]))return [NSString stringWithFormat:@"missing_contract:%@.%@",entry[0],entry[1]];
  if(![NSClassFromString(@"UIGlassEffect") respondsToSelector:NSSelectorFromString(@"effectWithStyle:")])return @"missing_glass_api";
  if(![NSClassFromString(@"UICornerConfiguration") respondsToSelector:NSSelectorFromString(@"capsuleConfiguration")]||
     ![UIVisualEffectView instancesRespondToSelector:NSSelectorFromString(@"setCornerConfiguration:")])return @"missing_corner_api";
  if(![NSClassFromString(@"UIButtonConfiguration") respondsToSelector:NSSelectorFromString(@"glassButtonConfiguration")])return @"missing_glass_button_api";
  return nil;
 }
 return @"requires_ios_26";
}
BOOL GSPhotosGlassAvailable(void){return GSUnavailableReason()==nil;}

static void GSCollectVisibleLabels(UIView *view,UIControl *segments,NSMutableArray<NSDictionary *> *items){
 if(view!=segments&&(view.hidden||view.alpha<=0.01))return;
 if([view isKindOfClass:UILabel.class]){
  NSString *text=((UILabel *)view).text;
  if(text.length&&text.length<48){
   CGPoint center=[view convertPoint:CGPointMake(CGRectGetMidX(view.bounds),CGRectGetMidY(view.bounds)) toView:segments];
   [items addObject:@{@"title":text,@"x":@(center.x)}];
  }
 }
 for(UIView *child in view.subviews)GSCollectVisibleLabels(child,segments,items);
}

static void GSCollectAccessibilityLabels(UIView *view,NSMutableArray<NSString *> *labels){
 NSString *label=view.accessibilityLabel;
 if(view.isAccessibilityElement&&label.length&&label.length<48&&![labels containsObject:label]&&
    [label rangeOfString:@"Search" options:NSCaseInsensitiveSearch].location==NSNotFound)[labels addObject:label];
 for(UIView *child in view.subviews)GSCollectAccessibilityLabels(child,labels);
}

static NSArray<NSString *> *GSTabTitles(UIControl *segments){
 NSMutableArray<NSDictionary *> *items=[NSMutableArray array];GSCollectVisibleLabels(segments,segments,items);
 [items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"x"] compare:b[@"x"]];}];
 NSMutableArray<NSString *> *titles=[NSMutableArray arrayWithCapacity:3];
 for(NSDictionary *item in items){NSString *title=item[@"title"];if(![titles containsObject:title])[titles addObject:title];if(titles.count==3)break;}
 if(titles.count<3){
  NSMutableArray<NSString *> *accessible=[NSMutableArray array];GSCollectAccessibilityLabels(segments,accessible);
  for(NSString *title in accessible){if(![titles containsObject:title])[titles addObject:title];if(titles.count==3)break;}
 }
 if(titles.count==3)return titles;
 return @[ @"Photos",@"Collections",@"Create"];
}

static void GSSyncTabSelection(GSPhotosGlassPair *pair){
 if(!pair.nativeTabController||!pair.segments)return;
 NSInteger selected=GSInteger(pair.segments,@"selectedSegmentIndex");
 if(selected<0||selected>=(NSInteger)pair.nativeTabController.viewControllers.count||pair.nativeTabController.selectedIndex==(NSUInteger)selected)return;
 BOOL changing=pair.changing;pair.changing=YES;pair.nativeTabController.selectedIndex=(NSUInteger)selected;pair.changing=changing;
}

static UITabBarController *GSCreateNativeTabController(GSPhotosGlassPair *pair){
 UITabBarController *tabs=[UITabBarController new];
 if(@available(iOS 18.0,*))tabs.mode=UITabBarControllerModeTabBar;
 tabs.delegate=pair;tabs.view.backgroundColor=UIColor.clearColor;tabs.view.opaque=NO;tabs.view.clipsToBounds=NO;
 NSArray<NSString *> *titles=GSTabTitles(pair.segments);
 NSArray<NSString *> *symbols=@[ @"photo.on.rectangle.angled",@"rectangle.stack",@"plus.circle"];
 NSMutableArray<UIViewController *> *controllers=[NSMutableArray arrayWithCapacity:3];
 for(NSInteger i=0;i<3;i++){
  UIViewController *itemController=[UIViewController new];
  itemController.view.backgroundColor=UIColor.clearColor;itemController.view.opaque=NO;itemController.view.userInteractionEnabled=NO;
  itemController.tabBarItem=[[UITabBarItem alloc]initWithTitle:titles[i] image:[UIImage systemImageNamed:symbols[i]] tag:i];
  [controllers addObject:itemController];
 }
 [tabs setViewControllers:controllers animated:NO];
 NSInteger selected=GSInteger(pair.segments,@"selectedSegmentIndex");
 if(selected>=0&&selected<(NSInteger)controllers.count)tabs.selectedIndex=(NSUInteger)selected;
 tabs.tabBar.translucent=YES;tabs.tabBar.clipsToBounds=NO;
 return tabs;
}

static UIButton *GSCreateNativeSearchButton(GSPhotosGlassPair *pair){
 Class configurationClass=NSClassFromString(@"UIButtonConfiguration");SEL selector=NSSelectorFromString(@"glassButtonConfiguration");
 if(![configurationClass respondsToSelector:selector])return nil;
 UIButtonConfiguration *configuration=((id(*)(id,SEL))objc_msgSend)(configurationClass,selector);
 if(![configuration isKindOfClass:UIButtonConfiguration.class])return nil;
 configuration.image=[UIImage systemImageNamed:@"magnifyingglass"]?:[pair.search imageForState:UIControlStateNormal];
 configuration.baseForegroundColor=UIColor.labelColor;configuration.cornerStyle=UIButtonConfigurationCornerStyleCapsule;
 UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];button.configuration=configuration;button.clipsToBounds=NO;
 button.accessibilityLabel=pair.search.accessibilityLabel?:@"Search";button.accessibilityHint=pair.search.accessibilityHint;
 button.accessibilityIdentifier=pair.search.accessibilityIdentifier;button.accessibilityTraits=pair.search.accessibilityTraits|UIAccessibilityTraitButton;
 [button addTarget:pair action:@selector(searchPressed:) forControlEvents:UIControlEventTouchUpInside];
 return button;
}

static void GSRestore(GSPhotosGlassPair *pair){
 if(!pair||pair.changing)return;
 pair.changing=YES;
 for(id object in @[pair.controller?:NSNull.null,pair.segments?:NSNull.null,pair.search?:NSNull.null])
  if(object!=NSNull.null&&objc_getAssociatedObject(object,&GSGlassPairKey)==pair)objc_setAssociatedObject(object,&GSGlassPairKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 pair.nativeTabController.delegate=nil;
 if(pair.nativeTabController.parentViewController){
  [pair.nativeTabController willMoveToParentViewController:nil];
  [pair.nativeTabController.view removeFromSuperview];
  [pair.nativeTabController removeFromParentViewController];
 }else [pair.nativeTabController.view removeFromSuperview];
 [pair.searchProxy removeFromSuperview];
 pair.segments.alpha=pair.segmentsAlpha;pair.segments.userInteractionEnabled=pair.segmentsInteraction;pair.segments.accessibilityElementsHidden=pair.segmentsAccessibilityHidden;
 pair.search.alpha=pair.searchAlpha;pair.search.userInteractionEnabled=pair.searchInteraction;pair.search.accessibilityElementsHidden=pair.searchAccessibilityHidden;
 [GSPairs removeObject:pair];pair.changing=NO;
}

static BOOL GSLayoutNativeControls(GSPhotosGlassPair *pair){
 if(!pair||pair.changing)return NO;
 if(!pair.host||pair.host!=pair.bar||!pair.bar.superview||pair.segments.superview!=pair.bar||pair.search.superview!=pair.bar||
    ![pair.bar.arrangedSubviews containsObject:pair.segments]||![pair.bar.arrangedSubviews containsObject:pair.search]||
    pair.nativeTabController.parentViewController!=pair.controller||pair.nativeTabController.view.superview!=pair.host||
    pair.nativeTabBar!=pair.nativeTabController.tabBar||pair.searchProxy.superview!=pair.host){GSRestore(pair);GSLastSkip=@"bottom_bar_hierarchy_changed";return NO;}
 pair.changing=YES;
 [pair.bar layoutIfNeeded];
 pair.segments.alpha=0;pair.segments.userInteractionEnabled=NO;pair.segments.accessibilityElementsHidden=YES;
 pair.search.alpha=0;pair.search.userInteractionEnabled=NO;pair.search.accessibilityElementsHidden=YES;
 CGRect tabFrame=[pair.segments convertRect:pair.segments.bounds toView:pair.host];
 CGRect searchFrame=[pair.search convertRect:pair.search.bounds toView:pair.host];
 // Standalone UITabBar uses the compact bar geometry seen in the broken build.
 // Keep the real UITabBar owned by UITabBarController, then size the controller's
 // viewport to Photos' floating pill and let the controller configure the iOS 26
 // platter/lens stack. The actual UITabBar is stretched to that viewport only
 // after the controller has performed its own system layout.
 CGFloat searchBottom=CGRectGetMaxY(searchFrame);
 if(searchBottom>CGRectGetMinY(tabFrame))tabFrame.size.height=searchBottom-CGRectGetMinY(tabFrame);
 pair.nativeTabController.view.frame=tabFrame;
 pair.nativeTabController.view.hidden=NO;pair.nativeTabController.view.alpha=1;
 [pair.nativeTabController.view setNeedsLayout];[pair.nativeTabController.view layoutIfNeeded];
 pair.nativeTabBar.frame=pair.nativeTabController.view.bounds;
 [pair.nativeTabBar setNeedsLayout];[pair.nativeTabBar layoutIfNeeded];
 pair.searchProxy.frame=searchFrame;pair.searchProxy.hidden=NO;pair.searchProxy.alpha=1;
 GSSyncTabSelection(pair);[pair.host bringSubviewToFront:pair.nativeTabController.view];[pair.host bringSubviewToFront:pair.searchProxy];
 pair.changing=NO;return YES;
}

@implementation GSPhotosGlassPair
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController{
 if(self.changing||tabBarController!=self.nativeTabController||!self.segments)return;
 NSUInteger index=[tabBarController.viewControllers indexOfObjectIdenticalTo:viewController];
 if(index==NSNotFound||index>=(NSUInteger)GSInteger(self.segments,@"numberOfSegments")||
    (NSInteger)index==GSInteger(self.segments,@"selectedSegmentIndex"))return;
 self.changing=YES;GSSetInteger(self.segments,@"setSelectedSegmentIndex:",(NSInteger)index);self.changing=NO;
}
- (void)searchPressed:(UIButton *)sender{
 if(self.changing||sender!=self.searchProxy||!self.search)return;
 [self.search sendActionsForControlEvents:UIControlEventTouchUpInside];
}
@end

static void GSUpdateController(UIViewController *controller){
 [GSControllers addObject:controller];
 GSPhotosGlassPair *previous=objc_getAssociatedObject(controller,&GSGlassPairKey);
 if(!GSPhotosGlassActiveThisLaunch()){GSRestore(previous);return;}
 if(previous.changing)return;
 UIStackView *bar=GSGet(controller,@"floatingBottomTabBar");
 UIControl *segments=GSGet(controller,@"floatingSegmentedControl");
 UIButton *search=GSGet(controller,@"floatingSearchButton");
 if(previous&&previous.bar==bar&&previous.segments==segments&&previous.search==search){GSLayoutNativeControls(previous);return;}
 GSRestore(previous);
 if(![bar isKindOfClass:UIStackView.class]||![segments isKindOfClass:UIControl.class]||![segments isKindOfClass:NSClassFromString(@"PHSSegmentedControl")]||
    ![search isKindOfClass:UIButton.class]||![search isKindOfClass:NSClassFromString(@"M3CButton")]||!bar.superview||
    segments.superview!=bar||search.superview!=bar||![bar.arrangedSubviews containsObject:segments]||![bar.arrangedSubviews containsObject:search]){GSLastSkip=@"floating_bottom_bar_not_found";return;}
 if(GSInteger(segments,@"numberOfSegments")!=3){GSLastSkip=@"unexpected_segment_count";return;}
 if(objc_getAssociatedObject(segments,&GSGlassPairKey)||objc_getAssociatedObject(search,&GSGlassPairKey)){GSLastSkip=@"bottom_bar_already_owned";return;}
 GSPhotosGlassPair *pair=[GSPhotosGlassPair new];pair.controller=controller;pair.bar=bar;pair.host=bar;pair.segments=segments;pair.search=search;
 pair.segmentsAlpha=segments.alpha;pair.searchAlpha=search.alpha;pair.segmentsInteraction=segments.userInteractionEnabled;pair.searchInteraction=search.userInteractionEnabled;
 pair.segmentsAccessibilityHidden=segments.accessibilityElementsHidden;pair.searchAccessibilityHidden=search.accessibilityElementsHidden;
 pair.nativeTabController=GSCreateNativeTabController(pair);pair.nativeTabBar=pair.nativeTabController.tabBar;pair.searchProxy=GSCreateNativeSearchButton(pair);
 if(!pair.nativeTabController||!pair.nativeTabBar||!pair.searchProxy){GSLastSkip=@"native_control_creation_failed";return;}
 for(id object in @[controller,segments,search])objc_setAssociatedObject(object,&GSGlassPairKey,pair,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 [GSPairs addObject:pair];
 [controller addChildViewController:pair.nativeTabController];[pair.host addSubview:pair.nativeTabController.view];[pair.nativeTabController didMoveToParentViewController:controller];
 [pair.host addSubview:pair.searchProxy];
 if(GSLayoutNativeControls(pair))GSLastSkip=nil;
}

static void GSVisitController(UIViewController *controller,NSMutableSet *seen){
 if(!controller||[seen containsObject:controller])return;[seen addObject:controller];
 if(controller.isViewLoaded&&[controller isKindOfClass:NSClassFromString(@"PHSTabBarController")])GSUpdateController(controller);
 for(UIViewController *child in controller.childViewControllers)GSVisitController(child,seen);GSVisitController(controller.presentedViewController,seen);
}
static void GSDiscoverControllers(void){
 if(!GSInstalled)return;NSMutableSet *seen=[NSMutableSet set];
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if([scene isKindOfClass:UIWindowScene.class])for(UIWindow *window in ((UIWindowScene *)scene).windows)GSVisitController(window.rootViewController,seen);
}
static void GSHook(Class cls,NSString *name,IMP replacement){SEL selector=NSSelectorFromString(name);Method method=class_getInstanceMethod(cls,selector);class_replaceMethod(cls,selector,replacement,method_getTypeEncoding(method));}
void GSInstallPhotosGlass(void){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSInstallPhotosGlass();});return;}
 if(GSInstalled||!GSPhotosGlassAvailable())return;GSControllers=NSHashTable.weakObjectsHashTable;GSPairs=NSHashTable.weakObjectsHashTable;
 Class cls=NSClassFromString(@"PHSTabBarController");SEL controllerLayoutSel=@selector(viewDidLayoutSubviews);IMP controllerLayout=method_getImplementation(class_getInstanceMethod(cls,controllerLayoutSel));
 GSHook(cls,@"viewDidLayoutSubviews",imp_implementationWithBlock(^(UIViewController *controller){((void(*)(id,SEL))controllerLayout)(controller,controllerLayoutSel);GSUpdateController(controller);}));
 cls=NSClassFromString(@"PHSSegmentedControl");SEL segmentLayoutSel=@selector(layoutSubviews);IMP segmentLayout=method_getImplementation(class_getInstanceMethod(cls,segmentLayoutSel));
 GSHook(cls,@"layoutSubviews",imp_implementationWithBlock(^(UIView *view){((void(*)(id,SEL))segmentLayout)(view,segmentLayoutSel);GSLayoutNativeControls(objc_getAssociatedObject(view,&GSGlassPairKey));}));
 SEL setIndexSel=NSSelectorFromString(@"setSelectedSegmentIndex:");IMP setIndex=method_getImplementation(class_getInstanceMethod(cls,setIndexSel));
 GSHook(cls,@"setSelectedSegmentIndex:",imp_implementationWithBlock(^(id control,NSInteger index){((void(*)(id,SEL,NSInteger))setIndex)(control,setIndexSel,index);GSPhotosGlassPair *pair=objc_getAssociatedObject(control,&GSGlassPairKey);if(pair&&!pair.changing)GSSyncTabSelection(pair);}));
 cls=NSClassFromString(@"M3CButton");SEL buttonLayoutSel=@selector(layoutSubviews);IMP buttonLayout=method_getImplementation(class_getInstanceMethod(cls,buttonLayoutSel));
 GSHook(cls,@"layoutSubviews",imp_implementationWithBlock(^(UIView *button){((void(*)(id,SEL))buttonLayout)(button,buttonLayoutSel);GSLayoutNativeControls(objc_getAssociatedObject(button,&GSGlassPairKey));}));
 GSInstalled=YES;GSDiscoverControllers();
}
void GSSetPhotosGlass(BOOL enabled){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSSetPhotosGlass(enabled);});return;}
 GSInstallPhotosGlass();if(enabled&&!GSInstalled)return;[NSUserDefaults.standardUserDefaults setBool:enabled forKey:GSPhotosGlassPreference];GSWriteDesignCompatibilityOverride(enabled);
 GSRestartRequired=enabled!=GSBootGlassEnabled;GSLastSkip=GSRestartRequired?@"restart_required":nil;
 if(!enabled||GSRestartRequired)for(GSPhotosGlassPair *pair in GSPairs.allObjects)GSRestore(pair);
 if(enabled&&!GSRestartRequired){GSDiscoverControllers();for(UIViewController *controller in GSControllers.allObjects)GSUpdateController(controller);}
}
NSDictionary *GSPhotosGlassSnapshot(void){
 if(!NSThread.isMainThread){__block NSDictionary *snapshot;dispatch_sync(dispatch_get_main_queue(),^{snapshot=GSPhotosGlassSnapshot();});return snapshot;}
 NSUInteger attached=0;for(GSPhotosGlassPair *pair in GSPairs.allObjects)if(pair.nativeTabController.parentViewController==pair.controller&&pair.nativeTabController.view.superview==pair.host&&pair.searchProxy.superview==pair.host&&pair.segments.superview==pair.bar&&pair.search.superview==pair.bar)attached++;
 NSString *unavailable=GSUnavailableReason();
 return @{@"enabled":@(GSPhotosGlassEnabled()),@"activeThisLaunch":@(GSPhotosGlassActiveThisLaunch()),@"available":@(unavailable==nil),@"hooksInstalled":@(GSInstalled),
  @"designCompatibilityOverride":@(GSDesignOverrideApplied),@"restartRequired":@(GSRestartRequired),@"controllersSeen":@(GSControllers.count),@"attachedBars":@(attached),
  @"reason":unavailable?:(GSRestartRequired?@"restart_required":attached?@"attached":GSLastSkip?:(GSPhotosGlassEnabled()?@"waiting_for_bottom_bar":@"disabled")),@"lastSkipReason":GSLastSkip?:NSNull.null};
}
__attribute__((constructor)) static void GSLoadPhotosGlass(void){
 @autoreleasepool{
  // Record the launch-time rollout state even for the UIKit fixture, whose
  // executable name is intentionally different from GooglePhotos.
  GSBootGlassEnabled=[NSUserDefaults.standardUserDefaults boolForKey:GSDesignCompatibilityOverride];GSDesignOverrideApplied=GSBootGlassEnabled;
  if(!GSPhotosHostSupported())return;
  // UIDesignRequiresCompatibility is cached before UIApplicationMain. Opt the
  // process back into the iOS 26 design before UIKit consumes that decision.
  GSBootGlassEnabled=GSPhotosGlassEnabled()&&GSPhotosGlassHostVersionSupported();GSWriteDesignCompatibilityOverride(GSBootGlassEnabled);GSDesignOverrideApplied=GSBootGlassEnabled;
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){GSInstallPhotosGlass();GSDiscoverControllers();}];
  dispatch_async(dispatch_get_main_queue(),^{GSInstallPhotosGlass();});
 }
}
