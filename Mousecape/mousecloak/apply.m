//
//  apply.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "create.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"
#import "NSBitmapImageRep+ColorSpace.h"
#import "MCDefs.h"
#import "innerShadow.h"
#import "outerGlow.h"
#import "scale.h"
#import <unistd.h>
#import <math.h>
#import <CoreImage/CoreImage.h>

static BOOL MCRegisterImagesForCursorName(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *name) {
    char *cursorName = (char *)name.UTF8String;
    int seed = 0;
    CGSConnectionID cid = CGSMainConnectionID();

    MMLog("--- Registering cursor ---");
    MMLog("  Name: %s", cursorName);
    MMLog("  CGSConnectionID: %d", cid);
    MMLog("  Size: %.1fx%.1f points", size.width, size.height);
    MMLog("  HotSpot: (%.1f, %.1f)", hotSpot.x, hotSpot.y);
    MMLog("  Frames: %lu, Duration: %.4f sec", (unsigned long)frameCount, frameDuration);
    MMLog("  Images array count: %lu", (unsigned long)[images count]);

#ifdef DEBUG
    // Log detailed image info in DEBUG mode
    for (NSUInteger i = 0; i < images.count; i++) {
        CGImageRef img = (__bridge CGImageRef)images[i];
        if (img) {
            MMLog("    Image[%lu]: %zux%zu pixels, %zu bpc, %zu bpp",
                  (unsigned long)i,
                  CGImageGetWidth(img),
                  CGImageGetHeight(img),
                  CGImageGetBitsPerComponent(img),
                  CGImageGetBitsPerPixel(img));
        }
    }
#endif

    // Validate and clamp hot spot to valid range to prevent CGError=1000
    // The hot spot coordinates must be within cursor dimensions (0 <= hotSpot < MCMaxHotspotValue)
    BOOL clamped = NO;
    if (hotSpot.x < 0) {
        hotSpot.x = 0;
        clamped = YES;
    } else if (hotSpot.x > MCMaxHotspotValue) {
        hotSpot.x = MCMaxHotspotValue;
        clamped = YES;
    }
    if (hotSpot.y < 0) {
        hotSpot.y = 0;
        clamped = YES;
    } else if (hotSpot.y > MCMaxHotspotValue) {
        hotSpot.y = MCMaxHotspotValue;
        clamped = YES;
    }

    if (clamped) {
        MMLog(YELLOW "  Hot spot was out of bounds, clamped to (%.1f, %.1f)" RESET, hotSpot.x, hotSpot.y);
    }

    MMLog("  Calling CGSRegisterCursorWithImages...");

    CGError err = CGSRegisterCursorWithImages(cid,
                                              cursorName,
                                              true,
                                              true,
                                              size,
                                              hotSpot,
                                              frameCount,
                                              frameDuration,
                                              (__bridge CFArrayRef)images,
                                              &seed);

    MMLog("  Result: %s (CGError=%d, seed=%d)",
          (err == kCGErrorSuccess) ? "SUCCESS" : "FAILED", err, seed);

    return (err == kCGErrorSuccess);
}

BOOL applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount, BOOL skipSynonyms) {
    MMLog("=== applyCursorForIdentifier ===");
    MMLog("  Identifier: %s", ident.UTF8String);
    MMLog("  Skip synonyms: %s", skipSynonyms ? "YES" : "NO");

    if (frameCount > 24 || frameCount < 1) {
        MMLog(BOLD RED "Frame count of %s out of range [1...24]", ident.UTF8String);
        return NO;
    }

    // When skipSynonyms is set, register only for this exact identifier.
    // This prevents system default cursors (e.g. ArrowCtx) from overwriting
    // related cursors that have custom images (e.g. ArrowS).
    if (skipSynonyms) {
        BOOL success = MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident);
        MMLog("  Direct registration result: %s", success ? "SUCCESS" : "FAILED");
        return success;
    }

    // Special handling for Arrow on newer macOS where the underlying name may have changed.
    BOOL isArrow = ([ident isEqualToString:@"com.apple.coregraphics.Arrow"] || [ident isEqualToString:@"com.apple.coregraphics.ArrowCtx"]);
    BOOL isIBeam = ([ident isEqualToString:@"com.apple.coregraphics.IBeam"] || [ident isEqualToString:@"com.apple.coregraphics.IBeamXOR"]);

    MMLog("  Is Arrow: %s, Is IBeam: %s", isArrow ? "YES" : "NO", isIBeam ? "YES" : "NO");

    if (isArrow) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCArrowSynonyms();
        MMLog("  Arrow synonyms to register: %lu", (unsigned long)synonyms.count);
        for (NSString *syn in synonyms) {
            MMLog("    - %s", syn.UTF8String);
        }

        // Register for all discovered Arrow-related names.
        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        // Also try the legacy identifier if it wasn't in the discovered set.
        if (![synonyms containsObject:ident]) {
            MMLog("  Trying legacy identifier: %s", ident.UTF8String);
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }

        // Reduce the chance of the Dock overriding the cursor immediately after registration.
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        MMLog("  Arrow registration result: %s", anySuccess ? "SUCCESS" : "FAILED");
        return anySuccess;
    }

    // Special handling for I-beam (text cursor) on newer macOS
    if (isIBeam) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCIBeamSynonyms();
        MMLog("  IBeam synonyms to register: %lu", (unsigned long)synonyms.count);
        for (NSString *syn in synonyms) {
            MMLog("    - %s", syn.UTF8String);
        }

        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        if (![synonyms containsObject:ident]) {
            MMLog("  Trying legacy identifier: %s", ident.UTF8String);
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        MMLog("  IBeam registration result: %s", anySuccess ? "SUCCESS" : "FAILED");
        return anySuccess;
    }

    // Check if this is a resize cursor that needs synonym expansion
    NSArray *resizeSynonyms = MCResizeSynonyms(ident);
    if (resizeSynonyms) {
        MMLog("  Resize synonyms to register: %lu", (unsigned long)resizeSynonyms.count);
        for (NSString *syn in resizeSynonyms) {
            MMLog("    - %s", syn.UTF8String);
        }
        BOOL anySuccess = NO;
        for (NSString *name in resizeSynonyms) {
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        MMLog("  Resize registration result: %s", anySuccess ? "SUCCESS" : "FAILED");
        return anySuccess;
    }

    // Default behavior for all other cursors.
    MMLog("  Using default registration");
    return MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident);
}

// Read system cursor data directly, bypassing the MCIsCursorRegistered check.
// This is needed because CoreCursorUnregisterAll() unregisters cursors, but
// system built-in cursors (com.apple.cursor.*) are still readable via CoreCursorCopyImages.
// Unlike capeWithIdentifier, this skips the MCIsCursorRegistered check and also
// calls CoreCursorSet first to activate the cursor before reading (required by CoreCursorCopyImages).
static NSDictionary * _Nullable systemCapeWithIdentifier(NSString *identifier) {
    NSUInteger frameCount;
    CGFloat frameDuration;
    CGPoint hotSpot;
    CGSize size;
    CFArrayRef representations = NULL;

    CGError error = 0;
    if (![identifier hasPrefix:@"com.apple.cursor"]) {
        // For named cursors (com.apple.coregraphics.*), CGSCopyRegisteredCursorImages
        // should work without activation
        error = CGSCopyRegisteredCursorImages(CGSMainConnectionID(), (char *)identifier.UTF8String, &size, &hotSpot, &frameCount, &frameDuration, &representations);
    } else {
        // For numbered cursors (com.apple.cursor.N), CoreCursorCopyImages reads the
        // ACTIVE cursor. We must call CoreCursorSet first to activate it, just like
        // dumpCursorsToFile does before reading.
        CGSCursorID cursorID = [[identifier pathExtension] intValue];
        MMLog("  systemCape: CoreCursorSet(%d) for %s", (int)cursorID, identifier.UTF8String);
        error = CoreCursorSet(CGSMainConnectionID(), cursorID);
        MMLog("  systemCape: CoreCursorSet result: %d", (int)error);
        if (error == noErr) {
            error = CoreCursorCopyImages(CGSMainConnectionID(), cursorID, &representations, &size, &hotSpot, &frameCount, &frameDuration);
            MMLog("  systemCape: CoreCursorCopyImages result: %d, reps=%lu", (int)error, (unsigned long)(representations ? CFArrayGetCount(representations) : 0));
        }
    }

    if (error || !representations || !CFArrayGetCount(representations)) {
        MMLog(YELLOW "  systemCape FAILED for %s: error=%d, reps=%p" RESET, identifier.UTF8String, (int)error, representations);
        return nil;
    }

    // CoreCursorCopyImages returns size={0,0} for numbered cursors (com.apple.cursor.N).
    // Infer point size from image dimensions.
    if (size.width < 1.0 || size.height < 1.0) {
        CGImageRef img = (__bridge CGImageRef)((__bridge NSArray *)representations).firstObject;
        if (img) {
            CGFloat inferredW = (CGFloat)CGImageGetWidth(img) / 2.0;
            CGFloat inferredH = (CGFloat)CGImageGetHeight(img) / 2.0;
            MMLog("  Inferred size for %s from image %.0fx%.0f -> %.1fx%.1f pt",
                  identifier.UTF8String,
                  (CGFloat)CGImageGetWidth(img), (CGFloat)CGImageGetHeight(img),
                  inferredW, inferredH);
            size = CGSizeMake(inferredW, inferredH);
        }
    }

    NSDictionary *dict = @{MCCursorDictionaryFrameCountKey: @(frameCount), MCCursorDictionaryFrameDuratiomKey: @(frameDuration), MCCursorDictionaryHotSpotXKey: @(hotSpot.x), MCCursorDictionaryHotSpotYKey: @(hotSpot.y), MCCursorDictionaryPointsWideKey: @(size.width), MCCursorDictionaryPointsHighKey: @(size.height), MCCursorDictionaryRepresentationsKey: (__bridge NSArray *)representations};

    CFRelease(representations);
    return dict;
}

// Apply unsharp mask sharpening to enhance cursor edge crispness after upscaling.
// Upscale + sharpen using Core Image for high quality.
// Uses Lanczos resampling (much sharper than bicubic) + CISharpenLuminance
// for perceptual edge enhancement. Falls back to CGContext if CIImage fails.
static CGImageRef _Nullable MCUpscaleAndSharpen(CGImageRef original, NSUInteger targetW, NSUInteger targetH, CGFloat sharpness) {
    @autoreleasepool {
        CIImage *ciImg = [CIImage imageWithCGImage:original];
        if (!ciImg) return NULL;

        CGFloat scaleW = (CGFloat)targetW / (CGFloat)CGImageGetWidth(original);
        CGFloat scaleH = (CGFloat)targetH / (CGFloat)CGImageGetHeight(original);

        // Lanczos scale transform — significantly sharper than CGContext bicubic
        CIFilter *lanczos = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        [lanczos setDefaults];
        [lanczos setValue:ciImg forKey:kCIInputImageKey];
        [lanczos setValue:@(scaleW) forKey:@"inputScale"];
        [lanczos setValue:@(scaleH / scaleW) forKey:@"inputAspectRatio"];
        CIImage *scaled = lanczos.outputImage;

        // Sharpen luminance — perceptual edge enhancement
        if (sharpness > 0.01) {
            CIFilter *sharpen = [CIFilter filterWithName:@"CISharpenLuminance"];
            [sharpen setDefaults];
            [sharpen setValue:scaled forKey:kCIInputImageKey];
            [sharpen setValue:@(sharpness) forKey:@"inputSharpness"];
            scaled = sharpen.outputImage;
        }

        // Render to CGImage
        CIContext *ciCtx = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        CGImageRef result = [ciCtx createCGImage:scaled fromRect:CGRectMake(0, 0, targetW, targetH)
                                        format:kCIFormatBGRA8
                                        colorSpace:CGColorSpaceCreateDeviceRGB()];
        return result;
    }
}

BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore, BOOL customScaleMode, BOOL skipSynonyms, BOOL isSystemDefault) {
    MMLog("=== applyCapeForIdentifier ===");
    MMLog("  Identifier: %s", identifier.UTF8String);
    MMLog("  Restore mode: %s", restore ? "YES" : "NO");

    if (!cursor || !identifier) {
        MMLog(BOLD RED "  Invalid cursor or identifier (bad seed)" RESET);
        return NO;
    }

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL innerShadow = MCFlag(MCPreferencesInnerShadowKey);
    BOOL outerGlow = MCFlag(MCPreferencesOuterGlowKey);
    BOOL pointer = MCCursorIsPointer(identifier);
    NSNumber *frameCount    = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = cursor[MCCursorDictionaryFrameDuratiomKey];

    MMLog("  Lefty mode: %s", lefty ? "YES" : "NO");
    MMLog("  Is pointer: %s", pointer ? "YES" : "NO");
    MMLog("  FrameCount: %s", frameCount.description.UTF8String);
    MMLog("  FrameDuration: %s", frameDuration.description.UTF8String);
    //    NSNumber *repeatCount   = cursor[MCCursorDictionaryRepeatCountKey];
    
    CGPoint hotSpot         = CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]);
    CGSize size             = CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]);
    NSArray *reps           = cursor[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *images  = [NSMutableArray array];

    MMLog("  HotSpot: (%.1f, %.1f)", hotSpot.x, hotSpot.y);
    MMLog("  Size: %.1fx%.1f", size.width, size.height);
    MMLog("  Representations count: %lu", (unsigned long)[reps count]);

    if (lefty && !restore) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    // Always select the highest resolution representation available.
    // Starting from the highest quality source ensures the system can scale
    // down cleanly rather than upscaling from a low-res rep (which causes pixelation).
    NSBitmapImageRep *bestRep = nil;
    NSUInteger bestPixelCount = 0;
    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object];
        } else {
            rep = [[NSBitmapImageRep alloc] initWithData:object];
        }
        rep = rep.retaggedSRGBSpace;

        NSUInteger pixelCount = (NSUInteger)rep.pixelsWide * (NSUInteger)rep.pixelsHigh;
        if (pixelCount > bestPixelCount) {
            bestPixelCount = pixelCount;
            bestRep = rep;
        }
    }
    MMLog("  Selected highest resolution representation: %lupx (%lux%lu)",
          (unsigned long)bestPixelCount, (unsigned long)bestRep.pixelsWide, (unsigned long)bestRep.pixelsHigh);

    if (bestRep) {
        if (!lefty || restore) {
            images[images.count] = (__bridge id)[bestRep CGImage];
        } else {
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:bestRep.pixelsWide
                                                                               pixelsHigh:bestRep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * bestRep.pixelsWide
                                                                             bitsPerPixel:32];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:bestRep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [bestRep drawInRect:NSMakeRect(0, 0, bestRep.pixelsWide, bestRep.pixelsHigh)
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                       fraction:1.0
                respectFlipped:NO
                         hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }

    // Upscale + sharpen low-resolution images when the source has significantly
    // fewer pixels than needed for crisp rendering at the target scale.
    // Uses Core Image Lanczos resampling (much sharper than bicubic) followed by
    // CISharpenLuminance for perceptual edge enhancement.
    // Since we always select the highest resolution representation, this primarily
    // helps system default cursors whose native images may be small (e.g. 64×64).
    if (images.count > 0 && bestRep) {
        NSUInteger srcPixels = (NSUInteger)bestRep.pixelsWide * (NSUInteger)bestRep.pixelsHigh;

        // Only upscale if the source image is too small to render crisply.
        // Cape cursors stored at 2048×2048 never need upscaling.
        // System defaults (typically 64×64) need upscaling at higher scales.
        if (srcPixels < (2048 * 2048)) {
            // Target: scale to at least 2048×2048 (matching cape quality).
            // This gives the system plenty of pixel data for sub-pixel rendering
            // at any scale up to 64x, producing results much closer to native
            // cursor quality.
            NSUInteger targetSide = 2048;
            NSUInteger targetPixelCount = targetSide * targetSide;

            if (targetPixelCount > srcPixels) {
                CGFloat scaleFactor = sqrt((CGFloat)targetPixelCount / (CGFloat)srcPixels);
                NSUInteger newWidth = (NSUInteger)(bestRep.pixelsWide * scaleFactor + 0.5);
                NSUInteger newHeight = (NSUInteger)(bestRep.pixelsHigh * scaleFactor + 0.5);
                // Ramp sharpening with scale: 0.3 at low zoom, up to 1.5 at high zoom
                CGFloat sharpness = 0.3 + (scaleFactor - 1.0) * 0.2;
                if (sharpness < 0.0) sharpness = 0.0;
                if (sharpness > 1.5) sharpness = 1.5;
                MMLog("  Upscale+sharpen: %lux%lu → %lux%lu (%.1fx), sharpness=%.2f",
                      (unsigned long)bestRep.pixelsWide, (unsigned long)bestRep.pixelsHigh,
                      (unsigned long)newWidth, (unsigned long)newHeight, scaleFactor, sharpness);

                NSMutableArray *processed = [NSMutableArray arrayWithCapacity:images.count];
                for (id imgObj in images) {
                    CGImageRef original = (__bridge CGImageRef)imgObj;
                    NSUInteger w = CGImageGetWidth(original);
                    NSUInteger h = CGImageGetHeight(original);
                    NSUInteger tw = (NSUInteger)(w * scaleFactor + 0.5);
                    NSUInteger th = (NSUInteger)(h * scaleFactor + 0.5);
                    CGImageRef result = MCUpscaleAndSharpen(original, tw, th, sharpness);
                    [processed addObject:(__bridge id)(result ?: original)];
                    if (result && result != original) CGImageRelease(result);
                }
                if (processed.count > 0) {
                    images = processed;
                }
            }
        }
    }

    // Apply inner shadow effect if enabled
    if (innerShadow && images.count > 0) {
        float radius = 32.0f;
        float intensity = 0.6f;
        MMLog("Applying inner shadow effect (radius=%.1f, intensity=%.1f)", radius, intensity);
        NSMutableArray *processed = [NSMutableArray arrayWithCapacity:images.count];
        for (id imgObj in images) {
            CGImageRef original = (__bridge CGImageRef)imgObj;
            CGImageRef shadowed = MCApplyInnerShadow(original, radius, intensity);
            [processed addObject:(__bridge id)(shadowed ?: original)];
            if (shadowed) CGImageRelease(shadowed);
        }
        images = processed;
    }

    // Apply outer glow effect if enabled
    if (outerGlow && images.count > 0) {
        float radius = 40.0f;
        float intensity = 0.7f;
        MMLog("Applying outer glow effect (radius=%.1f, intensity=%.1f)", radius, intensity);
        NSMutableArray *processed = [NSMutableArray arrayWithCapacity:images.count];
        for (id imgObj in images) {
            CGImageRef original = (__bridge CGImageRef)imgObj;
            CGImageRef glowing = MCApplyOuterGlow(original, radius, intensity);
            [processed addObject:(__bridge id)(glowing ?: original)];
            if (glowing) CGImageRelease(glowing);
        }
        images = processed;
    }

    // Per-cursor custom scaling
    if (customScaleMode) {
        NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
        MMLog("SCALE DEBUG per-cursor %s: perCursorScales=%@, customMode=YES, skipSynonyms=%s",
              identifier.UTF8String, perCursorScales, skipSynonyms ? "YES" : "NO");
        float desiredScale = [perCursorScales[identifier] floatValue];
        if (desiredScale <= 0.0f) desiredScale = 1.0f;

        float maxScale = cursorScale();
        if (maxScale <= 0.0f) maxScale = 1.0f;
        float ratio = (maxScale > 0) ? desiredScale / maxScale : 1.0f;
        MMLog("SCALE DEBUG per-cursor %s: desired=%.2f, maxScale=%.2f, ratio=%.3f",
              identifier.UTF8String, desiredScale, maxScale, ratio);

        if (ratio < 0.99f || ratio > 1.01f) {
            // Scale registration size and hotspot by ratio.
            // Images are NOT scaled — the representation selection (effectiveScale)
            // already picks the appropriate resolution. The system handles
            // image-to-registration-size mapping internally.
            size = CGSizeMake(size.width * ratio, size.height * ratio);
            MMLog("Custom scaling %s: desired=%.2f, ratio=%.3f, newSize=%.1fx%.1fpt",
                  identifier.UTF8String, desiredScale, ratio, size.width, size.height);

            hotSpot = CGPointMake(hotSpot.x * ratio, hotSpot.y * ratio);
            MMLog("Hotspot scaled by ratio %.3f: (%.1f, %.1f)", ratio, hotSpot.x, hotSpot.y);
        }
    }

    return applyCursorForIdentifier(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier, 0, skipSynonyms);
}

BOOL applyCape(NSDictionary *dictionary) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];

        MMLog("========================================");
        MMLog("=== APPLYING CAPE ===");
        MMLog("========================================");
        MMLog("Cape name: %s", name.UTF8String);
        MMLog("Cape identifier: %s", [dictionary[MCCursorDictionaryIdentifierKey] UTF8String]);
        MMLog("Cape version: %.2f", version.floatValue);
        MMLog("Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("Cursor identifiers:");
        for (NSString *key in cursors) {
            MMLog("  - %s", key.UTF8String);
        }

        // Save the current system scale BEFORE resetAllCursors() might reset it
        float savedScale = cursorScale();
        MMLog("Saved system scale before reset: %.2f", savedScale);

        MMLog("--- Calling resetAllCursors ---");
        resetAllCursors();
        MMLog("--- Calling backupAllCursors ---");
        backupAllCursors();

        // Read scale mode from direct C variable (not CFPreferences)
        BOOL isCustomMode = customScaleMode();

        if (isCustomMode) {
            float minScale = 16.0f;
            float maxScale = 1.0f;
            NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
            if (perCursorScales) {
                for (NSNumber *val in perCursorScales.allValues) {
                    float s = val.floatValue;
                    if (s > 0.0f && s < minScale) minScale = s;
                    if (s > maxScale) maxScale = s;
                }
            }
            // Custom mode: CGSSetCursorScale = 1.0, each cursor registers at its
            // desired point size directly (nativeSize × desiredScale).
            // Cape cursors use high-res images from the cape file (effectiveScale-based
            // representation selection picks the right resolution).
            // System defaults use native images with modest upscaling (acceptable ≤2x).
            float baseScale = 1.0f;
            MMLog("SCALE DEBUG: custom mode, maxScale=%.2f, baseScale=%.2f (direct registration)", maxScale, baseScale);
            setCursorScale(baseScale);
            // Save for listen.m to restore on session change
            MCSetDefault(@(baseScale), @"MCCustomMaxScale");
        } else {
            // Global mode: restore the exact scale that was active before reset
            MMLog("SCALE DEBUG: global mode, restoring to %.2f", savedScale);
            if (savedScale >= 0.5f && savedScale <= 16.0f) {
                setCursorScale(savedScale);
            } else {
                setCursorScale(defaultCursorScale());
            }
        }

        MMLog("--- Applying cursors ---");

        NSUInteger successCount = 0;
        NSUInteger skippedCount = 0;
        NSUInteger failedCount = 0;

        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);

            // Check if cursor has valid image data before attempting to apply
            NSArray *reps = cape[MCCursorDictionaryRepresentationsKey];
            if (!reps || reps.count == 0) {
                // System default cursors with no cape images are left alone
                // after resetAllCursors() — they are re-registered below with
                // per-cursor scaling via the MCEnumerateAllCursorIdentifiers loop.
                MMLog(YELLOW "  Skipping cursor %s - no image data (system default, re-registered below)" RESET, key.UTF8String);
                skippedCount++;
                continue;
            }

            BOOL success = applyCapeForIdentifier(cape, key, NO, isCustomMode, NO, NO);
            if (!success) {
                MMLog(YELLOW "  Failed to apply cursor %s - continuing with remaining cursors..." RESET, key.UTF8String);
                failedCount++;
            } else {
                successCount++;
            }
        }

        // In custom mode with CGSSetCursorScale=1.0, explicitly re-register system
        // default cursors (not in cape) with per-cursor scaling so they render at
        // their desired scale too.
        if (isCustomMode) {
            MMLog("--- Re-registering system defaults with per-cursor scale ---");
            // Only include cursors that were SUCCESSFULLY applied (have images).
            // Skipped cursors (no image data in cape) must still be handled.
            NSMutableSet *registeredKeys = [NSMutableSet set];
            for (NSString *key in cursors) {
                NSArray *reps = cursors[key][MCCursorDictionaryRepresentationsKey];
                if (reps && reps.count > 0) {
                    [registeredKeys addObject:key];
                }
            }
            MMLog("  registeredKeys count (successfully applied): %lu of %lu total cape entries",
                  (unsigned long)registeredKeys.count, (unsigned long)cursors.count);
            __block NSUInteger systemDefaultCount = 0;
            __block NSUInteger skippedByRegisteredKeys = 0;
            MCEnumerateAllCursorIdentifiers(^(NSString *name) {
                if ([registeredKeys containsObject:name]) {
                    skippedByRegisteredKeys++;
                    return; // Already registered as cape cursor
                }
                // Read system cursor data directly via CoreCursorSet/CoreCursorCopyImages.
                // Backups may not exist for com.apple.cursor.N identifiers since
                // MCIsCursorRegistered returns false for them.
                NSDictionary *systemData = systemCapeWithIdentifier(name);
                if (!systemData) {
                    return; // No system cursor data available
                }
                // Register with per-cursor scaling (isSystemDefault=YES to use highest res)
                BOOL ok = applyCapeForIdentifier(systemData, name, NO, YES, YES, YES);
                if (ok) {
                    systemDefaultCount++;
                } else {
                    MMLog(YELLOW "  Failed to re-register system default %s" RESET, name.UTF8String);
                }
            });
            MMLog("  Re-registered %lu system default cursors (skipped %lu by registeredKeys)", (unsigned long)systemDefaultCount, (unsigned long)skippedByRegisteredKeys);
        }

        MMLog("--- Application Summary ---");
        MMLog("  Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("  Successfully applied: %lu", (unsigned long)successCount);
        MMLog("  Skipped (no images): %lu", (unsigned long)skippedCount);
        MMLog("  Failed: %lu", (unsigned long)failedCount);

        // Consider the cape application successful if at least one cursor was applied
        if (successCount == 0) {
            MMLog(BOLD RED "No cursors were successfully applied!" RESET);
            return NO;
        }

        MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);

        if (skippedCount > 0 || failedCount > 0) {
            MMLog(BOLD GREEN "Applied %s with warnings (success: %lu, skipped: %lu, failed: %lu)" RESET,
                  name.UTF8String, (unsigned long)successCount, (unsigned long)skippedCount, (unsigned long)failedCount);
        } else {
            MMLog(BOLD GREEN "Applied %s successfully! (all %lu cursors)" RESET, name.UTF8String, (unsigned long)successCount);
        }
        MMLog("========================================");

        // Force cursor system to re-evaluate all registered cursors.
        // Without this nudge, cursor type switching (e.g. arrow→resize at window edges)
        // can break after resetAllCursors + register at non-1.0 scale.
        float currentScale = cursorScale();
        if (currentScale > 0.0f) {
            MMLog("Starting cursor scale nudge: target=%.2f", currentScale);
            
            CGError errBump = CGSSetCursorScale(CGSMainConnectionID(), currentScale + 0.3f);
            float afterBump = cursorScale();
            MMLog("Nudge bump: called with %.2f+0.3=%.2f, actual=%.2f, err=%d",
                  currentScale, currentScale + 0.3f, afterBump, errBump);
            
            // Small delay for cursor system to process the scale change
            usleep(30000); // 30ms
            
            // Restore with retry — the cursor system may not immediately apply the scale
            CGError errRestore = kCGErrorSuccess;
            float afterRestore = currentScale;
            for (int retry = 0; retry < 3; retry++) {
                errRestore = CGSSetCursorScale(CGSMainConnectionID(), currentScale);
                afterRestore = cursorScale();
                MMLog("Nudge restore attempt %d: target=%.2f, actual=%.2f, err=%d",
                      retry + 1, currentScale, afterRestore, errRestore);
                if (fabsf(afterRestore - currentScale) < 0.01f) {
                    break;
                }
                usleep(20000); // 20ms between retries
            }
            
            if (fabsf(afterRestore - currentScale) >= 0.01f) {
                MMLog(RED "Cursor scale nudge FAILED after 3 retries: final=%.2f, target=%.2f" RESET,
                      afterRestore, currentScale);
            } else {
                MMLog(GREEN "Cursor scale nudge completed: finalScale=%.2f" RESET, afterRestore);
            }
        }

        return YES;
    }
}

NSDictionary *applyCapeWithResult(NSDictionary *dictionary) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];

        MMLog("========================================");
        MMLog("=== APPLYING CAPE WITH RESULT ===");
        MMLog("========================================");
        MMLog("Cape name: %s", name.UTF8String);
        MMLog("Cape identifier: %s", [dictionary[MCCursorDictionaryIdentifierKey] UTF8String]);
        MMLog("Total cursors: %lu", (unsigned long)cursors.count);

        // Save the current system scale BEFORE resetAllCursors() might reset it
        float savedScale = cursorScale();
        MMLog("Saved system scale before reset: %.2f", savedScale);

        MMLog("--- Calling resetAllCursors ---");
        resetAllCursors();
        MMLog("--- Calling backupAllCursors ---");
        backupAllCursors();

        // Read scale mode from direct C variable (not CFPreferences)
        BOOL isCustomMode = customScaleMode();

        if (isCustomMode) {
            float minScale = 16.0f;
            float maxScale = 1.0f;
            NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
            if (perCursorScales) {
                for (NSNumber *val in perCursorScales.allValues) {
                    float s = val.floatValue;
                    if (s > 0.0f && s < minScale) minScale = s;
                    if (s > maxScale) maxScale = s;
                }
            }
            // Custom mode: CGSSetCursorScale = 1.0, each cursor registers at its
            // desired point size directly (nativeSize × desiredScale).
            // Cape cursors use high-res images from the cape file (effectiveScale-based
            // representation selection picks the right resolution).
            // System defaults use native images with modest upscaling (acceptable ≤2x).
            float baseScale = 1.0f;
            MMLog("SCALE DEBUG: custom mode, maxScale=%.2f, baseScale=%.2f (direct registration)", maxScale, baseScale);
            setCursorScale(baseScale);
            // Save for listen.m to restore on session change
            MCSetDefault(@(baseScale), @"MCCustomMaxScale");
        } else {
            MMLog("SCALE DEBUG: global mode, restoring to %.2f", savedScale);
            if (savedScale >= 0.5f && savedScale <= 16.0f) {
                setCursorScale(savedScale);
            } else {
                setCursorScale(defaultCursorScale());
            }
        }

        MMLog("--- Applying cursors ---");

        NSUInteger successCount = 0;
        NSUInteger skippedCount = 0;
        NSUInteger failedCount = 0;
        NSMutableArray *failedIdentifiers = [NSMutableArray array];
        NSMutableArray *skippedIdentifiers = [NSMutableArray array];

        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);

            // Check if cursor has valid image data before attempting to apply
            NSArray *reps = cape[MCCursorDictionaryRepresentationsKey];
            if (!reps || reps.count == 0) {
                // System default cursors with no cape images are left alone
                // after resetAllCursors() — they are re-registered below with
                // per-cursor scaling via the MCEnumerateAllCursorIdentifiers loop.
                MMLog(YELLOW "  Skipping cursor %s - no image data (system default, re-registered below)" RESET, key.UTF8String);
                skippedCount++;
                [skippedIdentifiers addObject:key];
                continue;
            }

            BOOL success = applyCapeForIdentifier(cape, key, NO, isCustomMode, NO, NO);
            if (!success) {
                MMLog(YELLOW "  Failed to apply cursor %s" RESET, key.UTF8String);
                failedCount++;
                [failedIdentifiers addObject:key];
            } else {
                successCount++;
            }
        }

        // In custom mode with balanced baseScale, system default cursors (not in cape)
        // would render at baseScale × native instead of their per-cursor scale.
        // Fix: explicitly re-register them with per-cursor scaling.
        if (isCustomMode) {
            MMLog("--- Re-registering system defaults with per-cursor scale ---");
            NSMutableSet *registeredKeys = [NSMutableSet set];
            for (NSString *key in cursors) {
                NSArray *reps = cursors[key][MCCursorDictionaryRepresentationsKey];
                if (reps && reps.count > 0) {
                    [registeredKeys addObject:key];
                }
            }
            __block NSUInteger systemDefaultCount = 0;
            __block NSUInteger skippedByRegisteredKeys = 0;
            MCEnumerateAllCursorIdentifiers(^(NSString *name) {
                if ([registeredKeys containsObject:name]) {
                    skippedByRegisteredKeys++;
                    return; // Already registered as cape cursor
                }
                // Read system cursor data directly — backups may not exist for
                // com.apple.cursor.N identifiers since MCIsCursorRegistered returns
                // false for them, so backupCursorForIdentifier never creates backups.
                NSDictionary *systemData = systemCapeWithIdentifier(name);
                if (!systemData) {
                    return; // No system cursor data available
                }
                // Register with per-cursor scaling (isSystemDefault=YES to use highest res)
                BOOL ok = applyCapeForIdentifier(systemData, name, NO, YES, YES, YES);
                if (ok) {
                    systemDefaultCount++;
                } else {
                    MMLog(YELLOW "  Failed to re-register system default %s" RESET, name.UTF8String);
                }
            });
            MMLog("  Re-registered %lu system default cursors (skipped %lu by registeredKeys)", (unsigned long)systemDefaultCount, (unsigned long)skippedByRegisteredKeys);
        }

        MMLog("--- Application Summary ---");
        MMLog("  Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("  Successfully applied: %lu", (unsigned long)successCount);
        MMLog("  Skipped (no images): %lu", (unsigned long)skippedCount);
        MMLog("  Failed: %lu", (unsigned long)failedCount);

        // Only save applied cursor preference if at least one cursor succeeded
        if (successCount > 0) {
            MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);
        }

        MMLog("========================================");

        // Force cursor system to re-evaluate all registered cursors.
        // Without this nudge, cursor type switching (e.g. arrow→resize at window edges)
        // can break after resetAllCursors + register at non-1.0 scale.
        float currentScale = cursorScale();
        if (currentScale > 0.0f) {
            MMLog("Starting cursor scale nudge: target=%.2f", currentScale);
            
            CGError errBump = CGSSetCursorScale(CGSMainConnectionID(), currentScale + 0.3f);
            float afterBump = cursorScale();
            MMLog("Nudge bump: called with %.2f+0.3=%.2f, actual=%.2f, err=%d",
                  currentScale, currentScale + 0.3f, afterBump, errBump);
            
            // Small delay for cursor system to process the scale change
            usleep(30000); // 30ms
            
            // Restore with retry — the cursor system may not immediately apply the scale
            CGError errRestore = kCGErrorSuccess;
            float afterRestore = currentScale;
            for (int retry = 0; retry < 3; retry++) {
                errRestore = CGSSetCursorScale(CGSMainConnectionID(), currentScale);
                afterRestore = cursorScale();
                MMLog("Nudge restore attempt %d: target=%.2f, actual=%.2f, err=%d",
                      retry + 1, currentScale, afterRestore, errRestore);
                if (fabsf(afterRestore - currentScale) < 0.01f) {
                    break;
                }
                usleep(20000); // 20ms between retries
            }
            
            if (fabsf(afterRestore - currentScale) >= 0.01f) {
                MMLog(RED "Cursor scale nudge FAILED after 3 retries: final=%.2f, target=%.2f" RESET,
                      afterRestore, currentScale);
            } else {
                MMLog(GREEN "Cursor scale nudge completed: finalScale=%.2f" RESET, afterRestore);
            }
        }

        // Return detailed result dictionary
        return @{
            @"success": @(successCount > 0),
            @"successCount": @(successCount),
            @"skippedCount": @(skippedCount),
            @"failedCount": @(failedCount),
            @"failedIdentifiers": [failedIdentifiers copy],
            @"skippedIdentifiers": [skippedIdentifiers copy]
        };
    }
}

BOOL applyCapeAtPath(NSString *path) {
    MMLog("========================================");
    MMLog("=== applyCapeAtPath ===");
    MMLog("========================================");
    MMLog("Input path: %s", path ? path.UTF8String : "(null)");

    // Validate path
    if (!path || path.length == 0) {
        MMLog(BOLD RED "Invalid path" RESET);
        return NO;
    }

    // Resolve symlinks and check for path traversal
    NSString *realPath = [path stringByResolvingSymlinksInPath];
    NSString *standardPath = [realPath stringByStandardizingPath];

    MMLog("Real path: %s", realPath.UTF8String);
    MMLog("Standard path: %s", standardPath.UTF8String);
    MMLog("File exists: %s", [[NSFileManager defaultManager] fileExistsAtPath:standardPath] ? "YES" : "NO");
    MMLog("File readable: %s", [[NSFileManager defaultManager] isReadableFileAtPath:standardPath] ? "YES" : "NO");

    // Validate file extension
    if (![[standardPath pathExtension] isEqualToString:@"cape"]) {
        MMLog(BOLD RED "Invalid file extension - must be .cape" RESET);
        return NO;
    }

    // Check file exists and is readable
    if (![[NSFileManager defaultManager] isReadableFileAtPath:standardPath]) {
        MMLog(BOLD RED "File not readable at path" RESET);
        return NO;
    }

    MMLog("Loading cape file...");
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:standardPath];
    if (cape) {
        MMLog("Cape file loaded successfully, applying...");
        return applyCape(cape);
    }
    MMLog(BOLD RED "Could not parse valid cape file" RESET);
    return NO;
}
