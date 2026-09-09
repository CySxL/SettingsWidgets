#import "SWBackgroundCache.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import <roothide.h>

#define SW_MAX_PIXEL 480
#define SW_MAX_FRAMES 60

__attribute__((visibility("hidden")))
static NSString *SWBaseDir(void) {
    return jbroot(@"/var/mobile/Library/Preferences/SettingsWidgets");
}

__attribute__((visibility("hidden")))
static NSString *SWCacheDir(NSString *sourceName) {
    NSString *base = [[sourceName lastPathComponent] stringByDeletingPathExtension];
    return [[SWBaseDir() stringByAppendingPathComponent:@".bgcache"] stringByAppendingPathComponent:base];
}

// Size + modification time, so a cache is invalidated if the source file changes.
__attribute__((visibility("hidden")))
static NSString *SWSourceSignature(NSString *fullPath) {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
    if (!attrs) return nil;
    unsigned long long size = [attrs fileSize];
    NSTimeInterval mod = [[attrs fileModificationDate] timeIntervalSince1970];
    return [NSString stringWithFormat:@"%llu-%.0f", size, mod];
}

// Force an image file to decode now (on the calling thread) instead of lazily at draw.
__attribute__((visibility("hidden")))
static UIImage *SWDecodeImageFile(NSString *path) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!source) return nil;
    NSDictionary *opts = @{ (id)kCGImageSourceShouldCacheImmediately: @YES };
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)opts);
    UIImage *result = nil;
    if (image) {
        result = [UIImage imageWithCGImage:image];
        CGImageRelease(image);
    }
    CFRelease(source);
    return result;
}

// Decode the source into downscaled thumbnail frames. Static images yield one frame.
__attribute__((visibility("hidden")))
static BOOL SWDecodeSource(NSString *fullPath, BOOL isGif, NSMutableArray<UIImage *> *outFrames, NSTimeInterval *outDuration) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:fullPath], NULL);
    if (!source) return NO;
    size_t count = CGImageSourceGetCount(source);
    if (count == 0) { CFRelease(source); return NO; }
    if (!isGif) count = 1;

    NSDictionary *thumbOpts = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceShouldCacheImmediately: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(SW_MAX_PIXEL)
    };
    NSUInteger stride = isGif ? ((count + SW_MAX_FRAMES - 1) / SW_MAX_FRAMES) : 1;
    if (stride < 1) stride = 1;

    NSTimeInterval duration = 0;
    for (size_t i = 0; i < count; i++) {
        @autoreleasepool {
            if (isGif) {
                NSTimeInterval delay = 0.1;
                CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
                if (properties) {
                    CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                    if (gifProperties) {
                        NSNumber *d = (__bridge NSNumber *)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                        if (!d || [d floatValue] == 0) {
                            d = (__bridge NSNumber *)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                        }
                        if ([d floatValue] > 0) delay = [d floatValue];
                    }
                    CFRelease(properties);
                }
                duration += delay;
                if (i % stride != 0) continue;
            }
            CGImageRef thumb = CGImageSourceCreateThumbnailAtIndex(source, i, (__bridge CFDictionaryRef)thumbOpts);
            if (thumb) {
                [outFrames addObject:[UIImage imageWithCGImage:thumb]];
                CGImageRelease(thumb);
            }
        }
    }
    CFRelease(source);
    if (outDuration) *outDuration = duration;
    return outFrames.count > 0;
}

__attribute__((visibility("hidden")))
void SWRebuildBackgroundCache(NSString *sourceFilename) {
    if (sourceFilename.length == 0) return;
    NSString *name = [sourceFilename lastPathComponent];
    NSString *fullPath = [SWBaseDir() stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:fullPath]) return;

    NSString *cacheDir = SWCacheDir(name);
    [fm removeItemAtPath:cacheDir error:nil];
    [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];

    BOOL isGif = [name.lowercaseString hasSuffix:@".gif"];
    NSMutableArray<UIImage *> *frames = [NSMutableArray array];
    NSTimeInterval duration = 0;
    if (!SWDecodeSource(fullPath, isGif, frames, &duration) || frames.count == 0) {
        [fm removeItemAtPath:cacheDir error:nil];
        return;
    }

    for (NSUInteger i = 0; i < frames.count; i++) {
        @autoreleasepool {
            NSData *png = UIImagePNGRepresentation(frames[i]);
            if (png) {
                NSString *fp = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"frame_%03lu.png", (unsigned long)i]];
                [png writeToFile:fp atomically:YES];
            }
        }
    }

    NSString *signature = SWSourceSignature(fullPath);
    NSDictionary *meta = @{
        @"type": isGif ? @"gif" : @"image",
        @"frames": @(frames.count),
        @"duration": @(duration),
        @"signature": signature ?: @""
    };
    [meta writeToFile:[cacheDir stringByAppendingPathComponent:@"meta.plist"] atomically:YES];
}

__attribute__((visibility("hidden")))
NSDictionary *SWLoadBackgroundCache(NSString *sourceFilename) {
    if (sourceFilename.length == 0) return nil;
    NSString *name = [sourceFilename lastPathComponent];
    NSString *fullPath = [SWBaseDir() stringByAppendingPathComponent:name];
    NSString *cacheDir = SWCacheDir(name);

    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:[cacheDir stringByAppendingPathComponent:@"meta.plist"]];
    if (![meta isKindOfClass:[NSDictionary class]]) return nil;

    NSString *signature = SWSourceSignature(fullPath);
    if (!signature || ![meta[@"signature"] isEqualToString:signature]) return nil;

    NSInteger n = [meta[@"frames"] integerValue];
    if (n <= 0) return nil;

    NSMutableArray<UIImage *> *frames = [NSMutableArray arrayWithCapacity:n];
    for (NSInteger i = 0; i < n; i++) {
        @autoreleasepool {
            NSString *fp = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"frame_%03ld.png", (long)i]];
            UIImage *img = SWDecodeImageFile(fp);
            if (img) [frames addObject:img];
        }
    }
    if (frames.count == 0) return nil;

    return @{ @"frames": frames, @"duration": meta[@"duration"] ?: @0 };
}

__attribute__((visibility("hidden")))
UIImage *SWLoadBackgroundFirstFrame(NSString *sourceFilename) {
    if (sourceFilename.length == 0) return nil;
    NSString *name = [sourceFilename lastPathComponent];
    NSString *fullPath = [SWBaseDir() stringByAppendingPathComponent:name];
    NSString *cacheDir = SWCacheDir(name);

    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:[cacheDir stringByAppendingPathComponent:@"meta.plist"]];
    if (![meta isKindOfClass:[NSDictionary class]]) return nil;

    NSString *signature = SWSourceSignature(fullPath);
    if (!signature || ![meta[@"signature"] isEqualToString:signature]) return nil;
    if ([meta[@"frames"] integerValue] <= 0) return nil;

    return SWDecodeImageFile([cacheDir stringByAppendingPathComponent:@"frame_000.png"]);
}
