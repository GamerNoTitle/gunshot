#pragma once
#import <Foundation/Foundation.h>
#import "GSLocalization.generated.h"

// Catalogs are compiled into each binary. No resource bundle is needed when
// Sideloadly or LiveContainer injects only the dylib into the host application.
static inline NSString *GSLanguageForPreferences(NSArray<NSString *> *languages) {
 for(NSString *language in languages){
  NSString *base=[[[language stringByReplacingOccurrencesOfString:@"_" withString:@"-"] componentsSeparatedByString:@"-"] firstObject].lowercaseString;
  if(GSLocalizationCatalogs()[base])return base;
 }
 return @"en";
}
static inline NSString *GSLanguageOverride(void) {
 NSString *value=[NSUserDefaults.standardUserDefaults stringForKey:@"dev.tqmane.gunshot.language"];
 return GSLocalizationCatalogs()[value?:@""]?value:@"system";
}
static inline NSString *GSLanguage(void) {
 NSString *value=GSLanguageOverride();
 return [value isEqual:@"system"]?GSLanguageForPreferences(NSLocale.preferredLanguages):value;
}
static inline void GSSetLanguage(NSString *language) {
 if(GSLocalizationCatalogs()[language?:@""])[NSUserDefaults.standardUserDefaults setObject:language forKey:@"dev.tqmane.gunshot.language"];
 else [NSUserDefaults.standardUserDefaults removeObjectForKey:@"dev.tqmane.gunshot.language"];
}
static inline NSString *GSL(NSString *key) {
 return GSLocalizationCatalogs()[GSLanguage()][key]?:key;
}

// Status is captured asynchronously and may outlive a language change. Translate
// known status text at display time without re-running authentication or IPC.
static inline NSString *GSLocalizedStatus(NSString *text, NSString *sourceLanguage) {
 if(!text)return nil;
 NSDictionary *source=GSLocalizationCatalogs()[sourceLanguage?:@"en"];
 for(NSString *key in source)if([source[key]isEqual:text])return GSL(key);
 NSArray *parts=[text componentsSeparatedByString:@" · "];
 if(parts.count>1){NSMutableArray *translated=[NSMutableArray array];for(NSString *part in parts)[translated addObject:GSLocalizedStatus(part,sourceLanguage)];return [translated componentsJoinedByString:@" · "];}
 return GSL(text); // Unknown server/system errors keep their original wording.
}
