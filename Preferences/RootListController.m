#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../UI/GSPanel.h"
@interface GSRootListController : PSListController
@end
@implementation GSRootListController
- (NSArray *)specifiers{
 if(!_specifiers){PSSpecifier *group=[PSSpecifier emptyGroupSpecifier];[group setProperty:@"Accounts, quality, background restrictions and upload queue are managed by gotohpd." forKey:@"footerText"];
 PSSpecifier *open=[PSSpecifier preferenceSpecifierNamed:@"Open GoToHP settings" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];open.buttonAction=@selector(openPanel);_specifiers=[@[group,open] mutableCopy];}return _specifiers;
}
- (void)openPanel{GSPanel *p=[[GSPanel alloc]initWithStyle:UITableViewStyleInsetGrouped];p.settingsMode=YES;[self presentViewController:[[UINavigationController alloc]initWithRootViewController:p] animated:YES completion:nil];}
@end
