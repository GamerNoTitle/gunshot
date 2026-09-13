#pragma once
#import <Foundation/Foundation.h>

// Audited host releases only. Every hook additionally checks its exact ABI.
typedef NS_ENUM(NSUInteger, GSPhotosProfile) {
 GSPhotosUnsupported = 0, GSPhotos7202, GSPhotos7920
};
static inline GSPhotosProfile GSPhotosHostProfile(void) {
 NSBundle *bundle=NSBundle.mainBundle;
 if(![[bundle objectForInfoDictionaryKey:@"CFBundleExecutable"]isEqual:@"GooglePhotos"])return GSPhotosUnsupported;
 NSString *version=[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
 if([version isEqual:@"7.20.2"])return GSPhotos7202;
 if([version isEqual:@"7.92.0"])return GSPhotos7920;
 return GSPhotosUnsupported;
}
static inline BOOL GSPhotosLegacyHost(void) { return GSPhotosHostProfile()==GSPhotos7202; }
static inline NSString *GSPhotosAssetCompletion(void) {
 return GSPhotosLegacyHost()?@"didCompleteWithSuccess:resultantMediaItem:errorCode:":@"didCompleteWithSuccess:resultantMediaItem:error:";
}
static inline const char *GSPhotosAssetCompletionABI(void) {
 return GSPhotosLegacyHost()?"v36@0:8B16@20q28":"v36@0:8B16@20@28";
}
