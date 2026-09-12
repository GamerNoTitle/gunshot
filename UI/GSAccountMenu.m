#import "GSAccountMenu.h"
#import "GSPanel.h"
#import "GSNativeAccount.h"
#import <objc/runtime.h>

// Private declarations are version/ABI checked before any hook is installed.
@interface NSObject (GSMenuItemConstruction)
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon itemType:(NSInteger)type;
@end
static NSUInteger (*GSSections)(id,SEL,id);
static NSUInteger (*GSItems)(id,SEL,id,NSUInteger);
static id (*GSItem)(id,SEL,id,NSIndexPath *);
static void (*GSAction)(id,SEL,id,NSIndexPath *);
static NSUInteger GSSection(id object,id controller){return GSSections(object,NSSelectorFromString(@"numberOfCustomSectionsForAccountMenuViewController:"),controller);}
static NSUInteger GSMenuSections(id object,SEL selector,id controller){return GSSections(object,selector,controller)+1;}
static NSUInteger GSMenuItems(id object,SEL selector,id controller,NSUInteger section){return section==GSSection(object,controller)?1:GSItems(object,selector,controller,section);}
static BOOL GSOwnItem(id object,id controller,NSIndexPath *path){return path.section==GSSection(object,controller)&&path.row==0;}
static id GSMenuItem(id object,SEL selector,id controller,NSIndexPath *path){
 if(!GSOwnItem(object,controller,path))return GSItem(object,selector,controller,path);
 // itemType 1 is the native custom-action row, verified at 0x100c0ca10.
 return [[NSClassFromString(@"OGLAccountMenuCustomItem") alloc]initWithTitle:@"GoToHP の設定" icon:[UIImage systemImageNamed:@"gearshape"] itemType:1];
}
static void GSMenuAction(id object,SEL selector,id controller,NSIndexPath *path){
 if(!GSOwnItem(object,controller,path)){GSAction(object,selector,controller,path);return;}
 if([controller isKindOfClass:UIViewController.class])GSPresentSettings(controller);
}
void GSInstallAccountMenu(void){
 static BOOL installed;
 if(installed||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"]||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]isEqual:@"7.92.0"])return;
 Class cls=NSClassFromString(@"PHSMyAccountMenuDataSource");
 NSArray *selectors=@[@"numberOfCustomSectionsForAccountMenuViewController:",@"accountMenuViewController:numberOfCustomItemsInSectionAtIndex:",@"accountMenuViewController:customItemAtIndexPath:",@"accountMenuViewController:performActionAtIndexPath:"];
 const char *encodings[]={"Q24@0:8@16","Q32@0:8@16Q24","@32@0:8@16@24","v32@0:8@16@24"};Method methods[4];
 for(NSUInteger i=0;i<4;i++){methods[i]=class_getInstanceMethod(cls,NSSelectorFromString(selectors[i]));if(!methods[i]||strcmp(method_getTypeEncoding(methods[i]),encodings[i]))return;}
 Method init=class_getInstanceMethod(NSClassFromString(@"OGLAccountMenuCustomItem"),@selector(initWithTitle:icon:itemType:));
 if(!init||strcmp(method_getTypeEncoding(init),"@40@0:8@16@24q32"))return;
 GSSections=(void *)method_setImplementation(methods[0],(IMP)GSMenuSections);
 GSItems=(void *)method_setImplementation(methods[1],(IMP)GSMenuItems);
 GSItem=(void *)method_setImplementation(methods[2],(IMP)GSMenuItem);
 GSAction=(void *)method_setImplementation(methods[3],(IMP)GSMenuAction);
 installed=YES;GSInstallNativeAccount();
}
