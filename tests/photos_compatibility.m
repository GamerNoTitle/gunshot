#import "../Shared/GSPhotosCompatibility.h"
#import <objc/runtime.h>
#include <assert.h>
static id version;
static NSString *executable=@"GooglePhotos";
@interface FixtureBundle : NSObject @end
@implementation FixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?executable:version;}
@end
static id Bundle(id object,SEL selector){return [FixtureBundle new];}
int main(void){@autoreleasepool{
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)Bundle);
 assert(GSPhotosProfileForVersion(nil)==GSPhotosUnsupported);
 for(id value in @[@123,NSNull.null,@"",@"7.20.1",@"7.20.3",@"7.20.2.1",@"7.91.99",@"6.999.0",@"7..93",@"7.93beta",@"7.93.-1",@" 8.0",@"8.0\n",@"99999999999999999999.0",@"8.0.0.0.1"]){version=value;assert(GSPhotosHostProfile()==GSPhotosUnsupported&&!GSPhotosHostAudited());}
 version=@"7.20.2";assert(GSPhotosLegacyHost()&&GSPhotosHostAudited());
 assert([GSPhotosAssetCompletion()hasSuffix:@"errorCode:"]);
 version=@"7.92.0";assert(GSPhotosHostProfile()==GSPhotosModern&&GSPhotosHostAudited());
 for(NSString *value in @[@"7.92",@"7.92.1",@"7.93.0",@"7.100.0",@"8.0",@"10.0.0",@"7.92.0.1"]){version=value;assert(GSPhotosHostProfile()==GSPhotosModern&&!GSPhotosHostAudited()&&!GSPhotosLegacyHost());assert([GSPhotosAssetCompletion()hasSuffix:@"error:"]);}
 executable=@"OtherApp";assert(GSPhotosHostProfile()==GSPhotosUnsupported&&!GSPhotosHostAudited());
 NSLog(@"PASS fixed legacy, numeric modern floor, future versions, malformed metadata and separate audit status");
}}
