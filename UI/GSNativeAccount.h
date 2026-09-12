#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT void GSInstallNativeAccount(void);
// Metadata only. Call on main; no token is returned to UI or persisted.
FOUNDATION_EXPORT NSDictionary *GSNativeAccountSummary(void);
// Worker-thread C ABI: caller owns the malloc-allocated result. NULL on failure.
FOUNDATION_EXPORT char *GSNativeBearer(const char *identifier);
// Main thread; compare native request identity without exposing credentials.
FOUNDATION_EXPORT BOOL GSNativeAccountMatches(id accountID);
