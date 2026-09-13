#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import "GSSandboxAccess.h"

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

int GSApplyIPCSandboxProfile(void) {
 static NSObject *lock;static dispatch_once_t once;
 dispatch_once(&once,^{lock=[NSObject new];});
 @synchronized(lock) {
  // Keep the library resident: libSandy may install its scoped iOS 16 lookup
  // adapter. A missing dependency must produce a diagnostic, not a dyld crash.
  static void *library;
  if(!library)library=dlopen(THEOS_PACKAGE_INSTALL_PREFIX "/usr/lib/libsandy.dylib",RTLD_NOW|RTLD_LOCAL);
  if(!library)return GS_SANDBOX_LIBRARY_MISSING;
  int (*apply)(const char *)=(int (*)(const char *))dlsym(library,"libSandy_applyProfile");
  if(!apply)return GS_SANDBOX_API_MISSING;
  // Do not cache a failed attempt: sandyd may be starting or restarting.
  // The root-owned profile grants only our service to three signing IDs.
  return apply(GS_IPC_SANDBOX_PROFILE);
 }
}
