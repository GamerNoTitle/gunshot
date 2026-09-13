#pragma once
#import <Foundation/Foundation.h>

// 7.20.2 is a fixed legacy adapter. 7.92.0+ may use the modern adapter;
// every integration still checks the selectors and exact ABI it calls.
typedef NS_ENUM(NSUInteger, GSPhotosProfile) {
 GSPhotosUnsupported = 0, GSPhotos7202, GSPhotosModern
};
static inline GSPhotosProfile GSPhotosProfileForVersion(id version) {
 if(![version isKindOfClass:NSString.class])return GSPhotosUnsupported;
 if([version isEqual:@"7.20.2"])return GSPhotos7202;
 NSArray<NSString *> *parts=[version componentsSeparatedByString:@"."];
 if(parts.count<1||parts.count>4)return GSPhotosUnsupported;
 NSUInteger components[4]={0};
 for(NSUInteger i=0;i<parts.count;i++){
  NSString *part=parts[i];
  if(!part.length||part.length>9||[part rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]invertedSet]].location!=NSNotFound)return GSPhotosUnsupported;
  components[i]=(NSUInteger)part.longLongValue;
 }
 return (components[0]>7||(components[0]==7&&components[1]>=92))?GSPhotosModern:GSPhotosUnsupported;
}
static inline GSPhotosProfile GSPhotosHostProfile(void) {
 NSBundle *bundle=NSBundle.mainBundle;
 if(![[bundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"])return GSPhotosUnsupported;
 return GSPhotosProfileForVersion([bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
}
static inline BOOL GSPhotosHostAudited(void) {
 if(GSPhotosHostProfile()==GSPhotosUnsupported)return NO;
 id version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
 return [version isEqual:@"7.20.2"]||[version isEqual:@"7.92.0"];
}
static inline BOOL GSPhotosLegacyHost(void) { return GSPhotosHostProfile()==GSPhotos7202; }
static inline NSString *GSPhotosAssetCompletion(void) {
 return GSPhotosLegacyHost()?@"didCompleteWithSuccess:resultantMediaItem:errorCode:":@"didCompleteWithSuccess:resultantMediaItem:error:";
}
static inline const char *GSPhotosAssetCompletionABI(void) {
 return GSPhotosLegacyHost()?"v36@0:8B16@20q28":"v36@0:8B16@20@28";
}
