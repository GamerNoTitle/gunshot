#pragma once
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
@interface GSPanel : UITableViewController
@property(nonatomic) BOOL settingsMode;
- (void)importAssets:(NSArray<PHAsset *> *)assets;
- (void)importURLs:(NSArray<NSURL *> *)urls;
@end
void GSPresent(UIViewController *host);
void GSInstallButton(UIWindow *window);
@interface GSUploadActivity : UIActivity
@end
