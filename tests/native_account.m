#import "host_profile.h"
#import "../UI/GSNativeAccount.h"
#import <objc/runtime.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
@interface GSFixtureBundle : NSObject
@end
@implementation GSFixtureBundle
- (id)objectForInfoDictionaryKey:(NSString *)key{return [key isEqual:@"CFBundleExecutable"]?@"GooglePhotos":GSFixtureVersion;}
@end
static id MainBundle(id object,SEL selector){static id bundle;if(!bundle)bundle=[GSFixtureBundle new];return bundle;}
@protocol SSOIdentity <NSObject>
@end
@interface GSIdentityFixture : NSObject <SSOIdentity>
@property(nonatomic) _Bool hasValidAuth;
@property(nonatomic,copy) NSString *userID;
@property(nonatomic,copy) NSString *userEmail;
@end
@implementation GSIdentityFixture
@end
@interface PHSAccount : NSObject {
@public id<SSOIdentity> _ssoIdentity;
}
@property(nonatomic,strong) id accountID;
@end
@implementation PHSAccount
@end
static void (^beforeCompletion)(void);
static NSUInteger authorizations;
@interface GSAuthorizerFixture : NSObject
@end
@implementation GSAuthorizerFixture
- (void)authorizeRequest:(NSMutableURLRequest *)request completionHandler:(void(^)(NSError *))completion{
 assert(NSThread.isMainThread);authorizations++;
 assert([request.URL.host isEqual:@"photos.googleapis.com"]);
 [request setValue:@"Bearer test-native-access-token" forHTTPHeaderField:@"Authorization"];
 if(beforeCompletion)beforeCompletion();completion(nil);
}
@end
@interface GSSSOFixture : NSObject
@end
@implementation GSSSOFixture
#ifdef GS_TEST_LEGACY
- (id)authorizationForIdentity:(id)identity scopes:(id)scopes{
 assert([identity isKindOfClass:GSIdentityFixture.class]);assert([[identity userID]isEqual:@"123"]);
 assert([scopes isEqual:@[@"https://www.googleapis.com/auth/photos.native"]]);return [GSAuthorizerFixture new];
}
#else
- (id)fetcherAuthorizerForAccountID:(id)account scopes:(id)scopes{
 assert([account isEqual:@"id-123"]);assert([scopes isEqual:@[@"https://www.googleapis.com/auth/photos.native"]]);return [GSAuthorizerFixture new];
}
#endif
@end
#ifdef GS_TEST_LEGACY
#define photosSSOService ssoService
#endif
@interface PHSAccountManagerImpl : NSObject
@property(nonatomic,strong) id viewingAccount;
@property(nonatomic,strong) id photosSSOService;
@end
@implementation PHSAccountManagerImpl
@end
static NSString *Fetch(const char *identifier){
 __block BOOL done=NO;__block NSString *result=nil;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  char *token=GSNativeBearer(identifier);NSString *value=token?[NSString stringWithUTF8String:token]:nil;free(token);
  dispatch_async(dispatch_get_main_queue(),^{result=value;done=YES;});
 });
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
 while(!done&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
 assert(done);return result;
}
int main(void){@autoreleasepool{
 method_setImplementation(class_getClassMethod(NSBundle.class,@selector(mainBundle)),(IMP)MainBundle);
 GSInstallNativeAccount();
 GSIdentityFixture *identity=[GSIdentityFixture new];identity.userID=@"123";identity.userEmail=@"test@example.com";identity.hasValidAuth=YES;
 PHSAccount *account=[PHSAccount new];account->_ssoIdentity=identity;account.accountID=@"id-123";
 PHSAccountManagerImpl *manager=[PHSAccountManagerImpl new];manager.viewingAccount=account;manager.photosSSOService=[GSSSOFixture new];
 assert([manager viewingAccount]==account);
 assert([GSNativeAccountSummary()[@"identifier"]isEqual:@"123"]);
 assert(GSNativeBearer("123")==NULL); // Main-thread caller must not block.
 assert([Fetch("123")isEqual:@"test-native-access-token"]);
 assert([Fetch("123")isEqual:@"test-native-access-token"]);assert(authorizations==2);
 assert(Fetch("wrong-account")==nil);assert(authorizations==2);
 identity.hasValidAuth=NO;assert(Fetch("123")==nil);identity.hasValidAuth=YES;
 beforeCompletion=^{manager.viewingAccount=nil;};assert(Fetch("123")==nil);
 assert(GSNativeAccountSummary()==nil);
 return 0;
}}
