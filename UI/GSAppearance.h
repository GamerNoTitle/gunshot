#pragma once
#import <UIKit/UIKit.h>

// Scoped to Gunshot controls; does not change the host's appearance or SDK gates.
FOUNDATION_EXPORT UIBarButtonItem *GSNavigationButton(NSString *title,id target,SEL action);
FOUNDATION_EXPORT BOOL GSApplyGlassButton(UIButton *button);
