#import "../UI/GSUnlimitedStorage.h"
#import <objc/runtime.h>
#include <assert.h>
static BOOL ready,throwEncode;
static NSUInteger actions;
@interface BundleFixture : NSObject @end
@implementation BundleFixture
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?@"GooglePhotos":@"7.20.2";}
@end
static id Bundle(id object,SEL selector){return [BundleFixture new];}
@interface OGLStringResources : NSObject @end
@implementation OGLStringResources
+ (id)sharedInstance{return [self new];}
- (id)stringForID:(int)identifier{assert(identifier==0x79);return ready?@"Unlimited storage":@"OneGoogleStorageCardUnlimitedTitle";}
@end
// Actual old shape: no title getter and no Swift/Bento renderer.
@interface OGLAccountMenuStorageCardData : NSObject <NSSecureCoding>
@property(nonatomic) NSInteger storageState;
@property(nonatomic) double usedStorage,totalStorage;
@property(nonatomic,copy) void(^cardActionCallback)(void);
@end
@implementation OGLAccountMenuStorageCardData
+ (BOOL)supportsSecureCoding{return YES;}
- (void)encodeWithCoder:(NSCoder *)coder{
 if(throwEncode)@throw [NSException exceptionWithName:@"Fixture" reason:nil userInfo:nil];
 [coder encodeInteger:self.storageState forKey:@"state"];
 [coder encodeDouble:self.usedStorage forKey:@"used"];
 [coder encodeDouble:self.totalStorage forKey:@"total"];
}
- (instancetype)initWithCoder:(NSCoder *)coder{if((self=[super init])){_storageState=[coder decodeIntegerForKey:@"state"];_usedStorage=[coder decodeDoubleForKey:@"used"];_totalStorage=[coder decodeDoubleForKey:@"total"];}return self;}
@end
@interface OGLAccountSelectorStorageCardItem : NSObject
@property(nonatomic) NSInteger storageState;
@end
@implementation OGLAccountSelectorStorageCardItem @end
@interface OGLAccountSelectorStorageCardCell : NSObject
+ (id)titleTextWithStorageItem:(id)item;
- (void)updateWithItem:(id)item;
@end
@implementation OGLAccountSelectorStorageCardCell
+ (id)titleTextWithStorageItem:(id)item{return @"Native title";}
- (void)updateWithItem:(id)item{}
@end
int main(int argc,const char **argv){@autoreleasepool{
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)Bundle);
 if(argc>1)method_setImplementation(class_getClassMethod(OGLStringResources.class,@selector(sharedInstance)),imp_implementationWithBlock(^id(id object){return nil;}));
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;[defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 GSInstallUnlimitedStorage();assert(GSUnlimitedStorageAvailable()&&GSUnlimitedStorageEnabled());
 OGLAccountMenuStorageCardData *data=[OGLAccountMenuStorageCardData new];data.storageState=0;data.usedStorage=6.55;data.totalStorage=15;data.cardActionCallback=^{actions++;};
 assert(![data respondsToSelector:NSSelectorFromString(@"title")]);assert(data.storageState==0);
 ready=YES;
 if(argc>1){assert(data.storageState==0);return 0;} // Missing resources never force an incomplete card.
 assert(data.storageState==2);
 OGLAccountSelectorStorageCardItem *item=[OGLAccountSelectorStorageCardItem new];item.storageState=data.storageState;
 [[OGLAccountSelectorStorageCardCell new]updateWithItem:item];assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Unlimited storage"]);
 data.cardActionCallback();assert(actions==1&&data.usedStorage==6.55&&data.totalStorage==15);
 NSError *error=nil;NSData *archive=[NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:&error];assert(archive&&!error);
 OGLAccountMenuStorageCardData *restored=[NSKeyedUnarchiver unarchivedObjectOfClass:data.class fromData:archive error:&error];assert(restored&&!error);
 throwEncode=YES;BOOL threw=NO;@try{[data encodeWithCoder:nil];}@catch(NSException *exception){threw=YES;}throwEncode=NO;assert(threw&&data.storageState==2);
 GSSetUnlimitedStorage(NO);assert(data.storageState==0&&restored.storageState==0&&restored.totalStorage==15&&restored.usedStorage==6.55);
 assert([[OGLAccountSelectorStorageCardCell titleTextWithStorageItem:item]isEqual:@"Native title"]);
 data.storageState=1;GSSetUnlimitedStorage(YES);assert(data.storageState==2);GSSetUnlimitedStorage(NO);assert(data.storageState==1);
 assert([GSUnlimitedStorageSnapshot()[@"legacyObserver"]boolValue]&&![GSUnlimitedStorageSnapshot()[@"bentoObserver"]boolValue]);
 [defaults removeObjectForKey:@"GSShowUnlimitedStorage"];
 NSLog(@"PASS 7.20.2 native UIKit card, no title getter, old resource ID, late resources, native archive and toggle restoration");
}}
