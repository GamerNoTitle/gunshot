#import "GSPhotosGlass.h"
#import "../Shared/GSPhotosCompatibility.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>

static NSString *const GSPhotosGlassPreference=@"GSPhotosBottomBarLiquidGlass";
static char GSGlassStateKey,GSNativeGlassKey;
static BOOL GSInstalled;
static NSHashTable *GSControllers,*GSControls;

// Only the two controls returned by PHSTabBarController are marked. Never change
// M3CLiquidGlass's global gate: the supplied host opts into compatibility mode.
@interface GSPhotosGlassState : NSObject
@property(nonatomic) BOOL search,contentOpaque,shadowOpaque,controlOpaque,adaptive;
@property(nonatomic) double elevation;
@property(nonatomic) NSInteger glassType;
@property(nonatomic,weak) UIView *content,*shadow,*owner;
@property(nonatomic,weak) UIVisualEffectView *nativeEffect;
@property(nonatomic,strong) UIVisualEffectView *effect;
@property(nonatomic,strong) UIColor *contentColor,*shadowColor;
@end
@implementation GSPhotosGlassState @end

static id GSGet(id object,NSString *name){
 if(!GSPhotosHasMethod(object_getClass(object),name,"@16@0:8"))return nil;
 return ((id(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name));
}
static NSInteger GSInteger(id object,NSString *name){return ((NSInteger(*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(name));}
static void GSSetType(id button,NSInteger type){((void(*)(id,SEL,NSInteger))objc_msgSend)(button,NSSelectorFromString(@"setGlassType:"),type);}
static double GSElevation(id shadow){return ((double(*)(id,SEL))objc_msgSend)(shadow,NSSelectorFromString(@"mdc_currentElevation"));}
static void GSSetElevation(id shadow,double value){((void(*)(id,SEL,double))objc_msgSend)(shadow,NSSelectorFromString(@"setElevation:"),value);}
static void GSSetAdaptive(id shadow,BOOL value){((void(*)(id,SEL,BOOL))objc_msgSend)(shadow,NSSelectorFromString(@"setAdaptiveBackgroundColorEnabled:"),value);}
BOOL GSPhotosGlassEnabled(void){return [NSUserDefaults.standardUserDefaults boolForKey:GSPhotosGlassPreference];}
BOOL GSPhotosGlassAvailable(void){
 if(@available(iOS 26.0,*)){
  id version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if(!GSPhotosHostSupported()||![version isKindOfClass:NSString.class]||
     [version rangeOfString:@"^[0-9]+\\.[0-9]+(?:\\.[0-9]+)?$" options:NSRegularExpressionSearch].location==NSNotFound)return NO;
  if([[version componentsSeparatedByString:@"."]count]==2)version=[version stringByAppendingString:@".0"];
  if([version compare:@"7.92.0" options:NSNumericSearch]==NSOrderedAscending)return NO;
  // Public glass API plus the native contracts recovered from 7.92.0. Later
  // versions with missing/incompatible APIs keep their original bottom bar.
  for(NSArray *entry in @[
   @[@"PHSTabBarController",@"viewDidLayoutSubviews",@"v16@0:8"],
   @[@"PHSTabBarController",@"floatingBottomTabBar",@"@16@0:8"],
   @[@"PHSTabBarController",@"floatingSegmentedControl",@"@16@0:8"],
   @[@"PHSTabBarController",@"floatingSearchButton",@"@16@0:8"],
   @[@"PHSSegmentedControl",@"layoutSubviews",@"v16@0:8"],
   @[@"PHSSegmentedControl",@"traitCollectionDidChange:",@"v24@0:8@16"],
   @[@"PHSShadowView",@"mdc_currentElevation",@"d16@0:8"],
   @[@"PHSShadowView",@"setElevation:",@"v24@0:8d16"],
   @[@"PHSShadowView",@"adaptiveBackgroundColorEnabled",@"B16@0:8"],
   @[@"PHSShadowView",@"setAdaptiveBackgroundColorEnabled:",@"v20@0:8B16"],
   @[@"M3CButton",@"glassType",@"q16@0:8"],
   @[@"M3CButton",@"setGlassType:",@"v24@0:8q16"],
   @[@"M3CButton",@"isGlassEnabled",@"B16@0:8"],
   @[@"M3CButton",@"glassEffectView",@"@16@0:8"],
   @[@"M3CMaterialGlassEffectView",@"isGlass",@"B16@0:8"],
   @[@"M3CMaterialGlassEffectView",@"glass",@"@16@0:8"],
   @[@"M3CMaterialGlassEffect",@"type",@"q16@0:8"]])
   if(!GSPhotosHasMethod(NSClassFromString(entry[0]),entry[1],[entry[2]UTF8String]))return NO;
  return [NSClassFromString(@"UIGlassEffect") respondsToSelector:NSSelectorFromString(@"effectWithStyle:")];
 }
 return NO;
}
static void GSRestore(UIView *control){
 GSPhotosGlassState *state=objc_getAssociatedObject(control,&GSGlassStateKey);if(!state)return;
 objc_setAssociatedObject(control,&GSGlassStateKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 if(state.search){
  objc_setAssociatedObject(state.nativeEffect,&GSNativeGlassKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  NSInteger type=GSInteger(control,@"glassType");
  GSSetType(control,type==2?state.glassType:type); // Recompute the native non-glass colors too.
 }else{
  [state.effect removeFromSuperview];control.opaque=state.controlOpaque;
  state.content.backgroundColor=state.contentColor;state.content.opaque=state.contentOpaque;
  state.shadow.backgroundColor=state.shadowColor;state.shadow.opaque=state.shadowOpaque;
  GSSetAdaptive(state.shadow,state.adaptive);GSSetElevation(state.shadow,state.elevation);
 }
 [GSControls removeObject:control];
}
static void GSLayoutGlass(UIView *control){
 GSPhotosGlassState *state=objc_getAssociatedObject(control,&GSGlassStateKey);if(!state||state.search)return;
 if(state.shadow.superview!=control||state.content.superview!=state.shadow){GSRestore(control);return;}
 // Native trait updates resolve a new background. Remember it for opt-out.
 if(![state.content.backgroundColor isEqual:UIColor.clearColor])state.contentColor=state.content.backgroundColor;
 if(![state.shadow.backgroundColor isEqual:UIColor.clearColor])state.shadowColor=state.shadow.backgroundColor;
 control.opaque=NO;state.content.backgroundColor=UIColor.clearColor;state.content.opaque=NO;
 state.shadow.backgroundColor=UIColor.clearColor;state.shadow.opaque=NO;
 state.effect.frame=control.bounds;state.effect.layer.cornerRadius=CGRectGetHeight(control.bounds)/2;
}
static void GSUpdateController(UIViewController *controller){
 [GSControllers addObject:controller];
 if(!GSPhotosGlassEnabled())return;
 UIView *bar=GSGet(controller,@"floatingBottomTabBar"),*segments=GSGet(controller,@"floatingSegmentedControl");
 id search=GSGet(controller,@"floatingSearchButton");
 if(![bar isKindOfClass:UIStackView.class]||![segments isKindOfClass:UIControl.class]||![search isKindOfClass:UIButton.class]||![segments isKindOfClass:NSClassFromString(@"PHSSegmentedControl")]||
    ![search isKindOfClass:NSClassFromString(@"M3CButton")]||segments.superview!=bar||[search superview]!=bar)return;
 if(!objc_getAssociatedObject(segments,&GSGlassStateKey)){
  UIView *shadow=nil,*content=nil;
  // The audited hierarchy is control > shadow > content (tab-bar accessibility
  // container). Do not use Swift ivar offsets or move native segment children.
  for(UIView *candidate in segments.subviews)if([candidate isKindOfClass:NSClassFromString(@"PHSShadowView")]){
   for(UIView *child in candidate.subviews)if(child.accessibilityTraits&UIAccessibilityTraitTabBar){
    if(content)return;shadow=candidate;content=child;
   }
  }
  if(!content)return;
  id effect=((id(*)(id,SEL,NSInteger))objc_msgSend)(NSClassFromString(@"UIGlassEffect"),NSSelectorFromString(@"effectWithStyle:"),0);
  if(![effect isKindOfClass:UIVisualEffect.class])return;
  GSPhotosGlassState *state=[GSPhotosGlassState new];state.content=content;state.shadow=shadow;
  state.contentColor=content.backgroundColor;state.shadowColor=shadow.backgroundColor;
  state.controlOpaque=segments.opaque;state.contentOpaque=content.opaque;state.shadowOpaque=shadow.opaque;state.elevation=GSElevation(shadow);
  state.adaptive=((BOOL(*)(id,SEL))objc_msgSend)(shadow,NSSelectorFromString(@"adaptiveBackgroundColorEnabled"));
  state.effect=[[UIVisualEffectView alloc]initWithEffect:effect];state.effect.userInteractionEnabled=NO;
  state.effect.accessibilityElementsHidden=YES;state.effect.clipsToBounds=YES;
  objc_setAssociatedObject(segments,&GSGlassStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[GSControls addObject:segments];
  GSSetAdaptive(shadow,NO);GSSetElevation(shadow,0);
  [segments insertSubview:state.effect atIndex:0];
 }
 GSLayoutGlass(segments);
 if(!objc_getAssociatedObject(search,&GSGlassStateKey)&&GSInteger(search,@"glassType")==0){
  id effect=GSGet(search,@"glassEffectView");
  if(![effect isKindOfClass:NSClassFromString(@"M3CMaterialGlassEffectView")])return;
  GSPhotosGlassState *state=[GSPhotosGlassState new];state.search=YES;state.owner=search;state.nativeEffect=effect;state.glassType=GSInteger(search,@"glassType");
  objc_setAssociatedObject(search,&GSGlassStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(effect,&GSNativeGlassKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[GSControls addObject:search];
  // Native type 2 maps to UIGlassEffectStyleRegular (0). Retain the real search
  // control's icon, state colors, targets, gestures, sizing and accessibility.
  GSSetType(search,2);
 }
}
static void GSHook(Class cls,NSString *name,IMP replacement){
 SEL selector=NSSelectorFromString(name);Method method=class_getInstanceMethod(cls,selector);
 class_replaceMethod(cls,selector,replacement,method_getTypeEncoding(method));
}
void GSInstallPhotosGlass(void){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSInstallPhotosGlass();});return;}
 if(GSInstalled||!GSPhotosGlassAvailable())return;
 GSControllers=NSHashTable.weakObjectsHashTable;GSControls=NSHashTable.weakObjectsHashTable;
 Class cls=NSClassFromString(@"PHSTabBarController");SEL selector=@selector(viewDidLayoutSubviews);
 IMP layout=method_getImplementation(class_getInstanceMethod(cls,selector));
 GSHook(cls,@"viewDidLayoutSubviews",imp_implementationWithBlock(^(UIViewController *controller){((void(*)(id,SEL))layout)(controller,selector);GSUpdateController(controller);}));
 cls=NSClassFromString(@"PHSSegmentedControl");
 IMP segmentLayout=method_getImplementation(class_getInstanceMethod(cls,@selector(layoutSubviews)));
 GSHook(cls,@"layoutSubviews",imp_implementationWithBlock(^(UIView *view){((void(*)(id,SEL))segmentLayout)(view,@selector(layoutSubviews));GSLayoutGlass(view);}));
 SEL trait=NSSelectorFromString(@"traitCollectionDidChange:");IMP oldTrait=method_getImplementation(class_getInstanceMethod(cls,trait));
 GSHook(cls,@"traitCollectionDidChange:",imp_implementationWithBlock(^(UIView *view,id previous){((void(*)(id,SEL,id))oldTrait)(view,trait,previous);GSLayoutGlass(view);}));
 cls=NSClassFromString(@"M3CButton");SEL enabled=NSSelectorFromString(@"isGlassEnabled");IMP oldEnabled=method_getImplementation(class_getInstanceMethod(cls,enabled));
 GSHook(cls,@"isGlassEnabled",imp_implementationWithBlock(^BOOL(id button){return objc_getAssociatedObject(button,&GSGlassStateKey)?GSInteger(button,@"glassType")!=0:((BOOL(*)(id,SEL))oldEnabled)(button,enabled);}));
 cls=NSClassFromString(@"M3CMaterialGlassEffectView");SEL isGlass=NSSelectorFromString(@"isGlass");IMP oldGlass=method_getImplementation(class_getInstanceMethod(cls,isGlass));
 GSHook(cls,@"isGlass",imp_implementationWithBlock(^BOOL(id effect){GSPhotosGlassState *state=objc_getAssociatedObject(effect,&GSNativeGlassKey);return state.owner&&objc_getAssociatedObject(state.owner,&GSGlassStateKey)==state?GSInteger(GSGet(effect,@"glass"),@"type")!=0:((BOOL(*)(id,SEL))oldGlass)(effect,isGlass);}));
 GSInstalled=YES;
}
void GSSetPhotosGlass(BOOL enabled){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{GSSetPhotosGlass(enabled);});return;}
 GSInstallPhotosGlass();if(enabled&&!GSPhotosGlassAvailable())return;
 [NSUserDefaults.standardUserDefaults setBool:enabled forKey:GSPhotosGlassPreference];
 if(!enabled)for(UIView *control in GSControls.allObjects)GSRestore(control);
 else for(UIViewController *controller in GSControllers.allObjects)GSUpdateController(controller);
}
__attribute__((constructor)) static void GSLoadPhotosGlass(void){
 @autoreleasepool{dispatch_async(dispatch_get_main_queue(),^{GSInstallPhotosGlass();});}
}
