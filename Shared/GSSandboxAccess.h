#pragma once

#define GS_IPC_SANDBOX_PROFILE "dev.tqmane.gunshot.ipc"
enum {
 GS_SANDBOX_LIBRARY_MISSING = -1,
 GS_SANDBOX_API_MISSING = -2,
};
// Other return values are libSandy status codes (0 success, 1 unavailable,
// 2 restricted). Success still requires a subsequent daemon lookup.
int GSApplyIPCSandboxProfile(void);
