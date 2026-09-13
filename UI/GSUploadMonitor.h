#pragma once
#import <Foundation/Foundation.h>

// UIKit lifecycle adapter, installed when Google Photos launches in either build.
void GSStartBackupIntegration(void);
// Main-thread lifecycle input; the monitor itself uses only Foundation.
void GSSetUploadHostForeground(BOOL foreground);
// Nonblocking snapshots, including while daemon/embedded requests are waiting.
BOOL GSUploadHostForeground(void);
NSDictionary *GSUploadMonitorSnapshot(void);
