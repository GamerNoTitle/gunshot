// Included by the existing settings UIKit smoke. No separate app/build/workflow.
#import "../UI/GSPhotosGlass.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface PHSShadowView : UIView
@property(nonatomic) double elevation;
@property(nonatomic) _Bool adaptiveBackgroundColorEnabled;
- (double)mdc_currentElevation;
@end
@implementation PHSShadowView
- (double)mdc_currentElevation{return self.elevation;}
- (void)setElevation:(double)value{_elevation=value;if(self.adaptiveBackgroundColorEnabled)self.backgroundColor=UIColor.systemBackgroundColor;}
@end
@interface PHSSegmentedControl : UIControl
@property(nonatomic,strong) PHSShadowView *shadow;
@property(nonatomic,strong) UIView *content,*selection;
@property(nonatomic) NSInteger selectedSegmentIndex;
@end
@implementation PHSSegmentedControl
- (instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){
  self.shadow=[PHSShadowView new];self.shadow.adaptiveBackgroundColorEnabled=YES;self.shadow.elevation=3;
  self.content=[UIView new];self.content.backgroundColor=UIColor.secondarySystemBackgroundColor;self.content.accessibilityTraits=UIAccessibilityTraitTabBar;
  self.selection=[UIView new];self.selection.backgroundColor=UIColor.tertiarySystemFillColor;
  [self addSubview:self.shadow];[self.shadow addSubview:self.content];[self.content addSubview:self.selection];
 }
 return self;
}
- (void)layoutSubviews{[super layoutSubviews];self.shadow.frame=self.bounds;self.content.frame=self.bounds;self.selection.frame=CGRectMake(4,4,80,48);}
- (void)traitCollectionDidChange:(UITraitCollection *)previous{[super traitCollectionDidChange:previous];self.content.backgroundColor=UIColor.tertiarySystemBackgroundColor;}
@end
@interface M3CMaterialGlassEffect : NSObject
@property(nonatomic) NSInteger type;
@end
@implementation M3CMaterialGlassEffect @end
@interface M3CMaterialGlassEffectView : UIVisualEffectView
@property(nonatomic,strong) M3CMaterialGlassEffect *glass;
- (_Bool)isGlass;
@end
@implementation M3CMaterialGlassEffectView
- (_Bool)isGlass{return NO;} // Models UIDesignRequiresCompatibility in the real IPA.
@end
@interface M3CButton : UIButton
@property(nonatomic,strong) M3CMaterialGlassEffectView *glassEffectView;
@property(nonatomic) NSInteger glassType;
- (_Bool)isGlassEnabled;
@end
@implementation M3CButton
- (instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){self.glassEffectView=[[M3CMaterialGlassEffectView alloc]initWithEffect:nil];self.glassEffectView.glass=[M3CMaterialGlassEffect new];[self addSubview:self.glassEffectView];}
 return self;
}
- (_Bool)isGlassEnabled{return NO;}
- (void)setGlassType:(NSInteger)value{
 self.glassEffectView.glass.type=value;
 self.glassEffectView.hidden=![self isGlassEnabled];
 if([self.glassEffectView isGlass])self.glassEffectView.effect=((id(*)(id,SEL,NSInteger))objc_msgSend)(NSClassFromString(@"UIGlassEffect"),NSSelectorFromString(@"effectWithStyle:"),0);
 else self.glassEffectView.effect=nil;
}
- (NSInteger)glassType{return self.glassEffectView.glass.type;}
@end
@interface PHSTabBarController : UIViewController
@property(nonatomic,strong) UIStackView *floatingBottomTabBar;
@property(nonatomic,strong) PHSSegmentedControl *floatingSegmentedControl;
@property(nonatomic,strong) M3CButton *floatingSearchButton;
@property(nonatomic) NSUInteger taps;
@end
@implementation PHSTabBarController
- (void)tap:(id)sender{self.taps++;}
- (void)viewDidLoad{
 [super viewDidLoad];self.floatingSegmentedControl=[[PHSSegmentedControl alloc]initWithFrame:CGRectMake(0,0,260,56)];
 self.floatingSearchButton=[[M3CButton alloc]initWithFrame:CGRectMake(0,0,56,56)];
 self.floatingSearchButton.accessibilityLabel=@"Search";
 [self.floatingSearchButton addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
 [self.floatingSegmentedControl addTarget:self action:@selector(tap:) forControlEvents:UIControlEventValueChanged];
 self.floatingBottomTabBar=[[UIStackView alloc]initWithArrangedSubviews:@[self.floatingSegmentedControl,self.floatingSearchButton]];[self.view addSubview:self.floatingBottomTabBar];
}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];}
@end
static id (*GSOriginalBundleInfo)(id,SEL,id);
static NSString *GSFixturePhotosVersion;
static id GSGlassBundleInfo(id bundle,SEL selector,id key){
 if(bundle==NSBundle.mainBundle){
  if([key isEqual:@"CFBundleExecutable"])return @"GooglePhotos";
  if([key isEqual:@"CFBundleShortVersionString"])return GSFixturePhotosVersion;
 }
 return GSOriginalBundleInfo(bundle,selector,key);
}
#define GS_GLASS_CHECK(value) do{if(!(value)){NSLog(@"FAIL bottom glass: %s",#value);return NO;}}while(0)
static BOOL GSCheckPhotosGlass(GSPanel *panel){
 BOOL modern=NO;if(@available(iOS 26.0,*))modern=YES;
 Method info=class_getInstanceMethod(NSBundle.class,@selector(objectForInfoDictionaryKey:));
 GSOriginalBundleInfo=(void *)method_setImplementation(info,(IMP)GSGlassBundleInfo);
 for(NSString *version in @[@"7.20.2",@"7.91.9",@"7.9.20",@"unknown",@"",@"7.92.0-beta"]){GSFixturePhotosVersion=version;GS_GLASS_CHECK(!GSPhotosGlassAvailable());}
 for(NSString *version in @[@"7.92.0",@"7.92",@"7.100.0",@"8.0.0"]){GSFixturePhotosVersion=version;GS_GLASS_CHECK(GSPhotosGlassAvailable()==modern);}
 GSFixturePhotosVersion=@"7.92.0";GSSetPhotosGlass(NO);GSInstallPhotosGlass();GSInstallPhotosGlass();
 PHSTabBarController *controller=[PHSTabBarController new];[controller loadViewIfNeeded];[controller viewDidLayoutSubviews];
 PHSSegmentedControl *segments=controller.floatingSegmentedControl;M3CButton *search=controller.floatingSearchButton;
 GS_GLASS_CHECK(!GSPhotosGlassEnabled()&&segments.subviews.count==1&&search.glassType==0);
 UITableViewCell *cell=[panel tableView:panel.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:6]];
 UISwitch *toggle=(UISwitch *)cell.accessoryView;
 GS_GLASS_CHECK([cell.textLabel.text isEqual:@"Google Photos · Liquid Glass"]&&[toggle isKindOfClass:UISwitch.class]&&!toggle.on&&toggle.enabled==modern);
 toggle.on=YES;[toggle sendActionsForControlEvents:UIControlEventValueChanged];
 GS_GLASS_CHECK(GSPhotosGlassEnabled()==modern);
 if(modern){
  GS_GLASS_CHECK(segments.subviews.count==2&&[segments.subviews.firstObject isKindOfClass:UIVisualEffectView.class]);
  UIVisualEffectView *glass=(UIVisualEffectView *)segments.subviews.firstObject;
  GS_GLASS_CHECK([glass.effect isKindOfClass:NSClassFromString(@"UIGlassEffect")]&&!glass.userInteractionEnabled&&glass.accessibilityElementsHidden);
  GS_GLASS_CHECK(segments.shadow.elevation==0&&!segments.shadow.adaptiveBackgroundColorEnabled&&[segments.shadow.backgroundColor isEqual:UIColor.clearColor]&&[segments.content.backgroundColor isEqual:UIColor.clearColor]);
  GS_GLASS_CHECK(search.glassType==2&&[search isGlassEnabled]&&[search.glassEffectView isGlass]&&search.glassEffectView.effect);
  GS_GLASS_CHECK([search.accessibilityLabel isEqual:@"Search"]&&segments.selection.superview==segments.content);
  segments.selectedSegmentIndex=2;[segments sendActionsForControlEvents:UIControlEventValueChanged];[search sendActionsForControlEvents:UIControlEventTouchUpInside];GS_GLASS_CHECK(controller.taps==2&&segments.selectedSegmentIndex==2);
  segments.frame=CGRectMake(0,0,360,64);[segments layoutSubviews];
  GS_GLASS_CHECK(CGRectEqualToRect(glass.frame,segments.bounds)&&glass.layer.cornerRadius==32);
  [segments traitCollectionDidChange:nil];GS_GLASS_CHECK([segments.content.backgroundColor isEqual:UIColor.clearColor]);
  // Native methods outside the returned bottom bar must stay in compatibility mode.
  M3CButton *unrelated=[M3CButton new];unrelated.glassType=2;GS_GLASS_CHECK(![unrelated isGlassEnabled]&&![unrelated.glassEffectView isGlass]);
  PHSTabBarController *second=[PHSTabBarController new];[second loadViewIfNeeded];[second viewDidLayoutSubviews];
  [controller viewDidLayoutSubviews];GS_GLASS_CHECK(segments.subviews.count==2&&second.floatingSegmentedControl.subviews.count==2);
  GSSetPhotosGlass(NO);GSSetPhotosGlass(NO);
  GS_GLASS_CHECK(segments.subviews.count==1&&segments.shadow.elevation==3&&segments.shadow.adaptiveBackgroundColorEnabled&&[segments.content.backgroundColor isEqual:UIColor.tertiarySystemBackgroundColor]);
  GS_GLASS_CHECK(search.glassType==0&&![search isGlassEnabled]&&!search.glassEffectView.effect&&second.floatingSearchButton.glassType==0&&second.floatingSegmentedControl.subviews.count==1);
  // Missing/changed native view structure is not repaired by guessing/reparenting.
  segments.content.accessibilityTraits=0;GSSetPhotosGlass(YES);GS_GLASS_CHECK(segments.subviews.count==1&&search.glassType==0);GSSetPhotosGlass(NO);
  segments.content.accessibilityTraits=UIAccessibilityTraitTabBar;GSSetPhotosGlass(YES);GS_GLASS_CHECK(segments.subviews.count==2&&search.glassType==2);GSSetPhotosGlass(NO);
 }else{GS_GLASS_CHECK(segments.subviews.count==1&&search.glassType==0);}
 method_setImplementation(info,(IMP)GSOriginalBundleInfo);
 GS_GLASS_CHECK(!GSPhotosGlassAvailable());
 NSLog(@"PASS bottom glass OS/version gates, opt-in setting, native compatibility isolation, layouts, targets, theme restoration, multiple bars and unknown hierarchy");
 return YES;
}
#undef GS_GLASS_CHECK
