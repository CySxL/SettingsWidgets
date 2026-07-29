#import <Foundation/Foundation.h>

// Decodes a custom background (image or GIF) from the SettingsWidgets preferences
// directory into downscaled frames stored on disk, so opening Settings does not have
// to re-parse the original file every time.
//
// sourceFilename is the stored file name (e.g. "bg1.gif"); only the last path
// component is used.

__attribute__((visibility("hidden"))) void SWRebuildBackgroundCache(NSString *sourceFilename);

// Returns @{ @"frames": NSArray<UIImage *>, @"duration": NSNumber } for a valid,
// up-to-date cache, or nil if the cache is missing or stale.
__attribute__((visibility("hidden"))) NSDictionary *SWLoadBackgroundCache(NSString *sourceFilename);
