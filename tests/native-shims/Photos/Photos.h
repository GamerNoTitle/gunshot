#import <Foundation/Foundation.h>
@interface PHAsset : NSObject
@property(nonatomic,copy) NSString *localIdentifier;
@property(nonatomic,strong) NSDate *creationDate;
@end
