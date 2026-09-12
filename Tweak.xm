#import <UIKit/UIKit.h>
#import "UI/GSPanel.h"
%hook UIWindow
- (void)becomeKeyWindow {
 %orig;
 GSInstallButton(self);
}
%end
%hook UIActivityViewController
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities {
 NSMutableArray *all=activities?[activities mutableCopy]:[NSMutableArray array];
 GSUploadActivity *upload=[GSUploadActivity new];
 if([upload canPerformWithActivityItems:items])[all addObject:upload];
 return %orig(items,all);
}
%end
