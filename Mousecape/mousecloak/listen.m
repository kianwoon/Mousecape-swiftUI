//
//  listen.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "listen.h"
#import "apply.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "MCPrefs.h"
#import "MCDefs.h"
#import "CGSCursor.h"
#import <Cocoa/Cocoa.h>

// Forward declaration for cleanup
static void unregisterDisplayCallback(void);

// Static references for session monitor cleanup
static CFRunLoopSourceRef g_sessionMonitorRLS = NULL;

NSString *appliedCapePathForUser(NSString *user) {
    // Validate user - must not be empty or contain path separators
    if (!user || user.length == 0 || [user containsString:@"/"] || [user containsString:@".."]) {
        MMLog(BOLD RED "Invalid username" RESET);
        return nil;
    }

    NSString *home = NSHomeDirectoryForUser(user);
    if (!home) {
        MMLog(BOLD RED "Could not get home directory for user" RESET);
        return nil;
    }

    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, (NSString *)kCFPreferencesCurrentHost);

    // Validate identifier - remove any path traversal attempts
    if (ident && ([ident containsString:@"/"] || [ident containsString:@".."])) {
        MMLog(BOLD RED "Invalid cape identifier" RESET);
        return nil;
    }

    if (!ident || ident.length == 0) {
        return nil;
    }

    NSString *appSupport = [home stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *capePath = [[[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByAppendingPathComponent:ident] stringByAppendingPathExtension:@"cape"];

    // Ensure the final path is within the expected directory
    NSString *standardPath = [capePath stringByStandardizingPath];
    NSString *expectedPrefix = [[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByStandardizingPath];
    if (![standardPath hasPrefix:expectedPrefix]) {
        MMLog(BOLD RED "Path traversal detected" RESET);
        return nil;
    }

    return capePath;
}

static void UserSpaceChanged(SCDynamicStoreRef	store, CFArrayRef changedKeys, void *info) {
    // Skip if refreshSystemDefaultCursors is mid-extraction at 64x.
    // Re-entering would read the boosted 64x scale and "restore" to it permanently.
    if (g_refreshingSystemDefaults) {
        MMLog(YELLOW "UserSpaceChanged: refresh in progress, skipping" RESET);
        return;
    }

    MMLog("========================================");
    MMLog("=== USER SPACE CHANGED EVENT ===");
    MMLog("========================================");

    CFStringRef currentConsoleUser = SCDynamicStoreCopyConsoleUser(store, NULL, NULL);

    MMLog("Console user: %s", currentConsoleUser ? [(__bridge NSString *)currentConsoleUser UTF8String] : "(null)");
    MMLog("Changed keys count: %ld", CFArrayGetCount(changedKeys));

    if (!currentConsoleUser || CFEqual(currentConsoleUser, CFSTR("loginwindow"))) {
        MMLog("Skipping - loginwindow or no user");
        if (currentConsoleUser) CFRelease(currentConsoleUser);
        return;
    }

    NSString *appliedPath = appliedCapePathForUser((__bridge NSString *)currentConsoleUser);
    MMLog(BOLD GREEN "User Space Changed to %s, applying cape..." RESET, [(__bridge NSString *)currentConsoleUser UTF8String]);
    MMLog("Cape path: %s", appliedPath ? appliedPath.UTF8String : "(none)");

    // Only attempt to apply if there's a valid cape path
    if (appliedPath) {
        BOOL success = applyCapeAtPath(appliedPath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
        if (!success) {
            MMLog(BOLD RED "Application of cape failed" RESET);
        }
    } else {
        MMLog("No cape configured for user");
        // Refresh system defaults at the current scale to prevent pixelation
        refreshSystemDefaultCursors();
    }

    CFRelease(currentConsoleUser);
}

void reconfigurationCallback(CGDirectDisplayID display,
	CGDisplayChangeSummaryFlags flags,
	void *userInfo) {
    // Skip if refreshSystemDefaultCursors is mid-extraction at 64x.
    if (g_refreshingSystemDefaults) {
        MMLog(YELLOW "Reconfig: refresh in progress, skipping" RESET);
        return;
    }

    // Skip the "begin" phase — macOS fires this callback twice per event:
    // once before the change (begin flag set) and once after (no begin flag).
    // Only acting on the "after" phase prevents double re-application.
    if (flags & kCGDisplayBeginConfigurationFlag) {
        MMLog("Display %u reconfiguration BEGIN phase — skipping", display);
        return;
    }

    MMLog("========================================");
    MMLog("=== DISPLAY RECONFIGURATION EVENT ===");
    MMLog("========================================");
    MMLog("Display ID: %u", display);
    MMLog("Flags: 0x%x", flags);

    NSString *capePath = appliedCapePathForUser(NSUserName());
    MMLog("Cape path: %s", capePath ? capePath.UTF8String : "(none)");

    if (capePath) {
        BOOL success = applyCapeAtPath(capePath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
    } else {
        // Refresh system defaults at the current scale to prevent pixelation
        refreshSystemDefaultCursors();
    }
}


void listener(void) {
#ifdef DEBUG
    MCLoggerInit();
#endif

    MMLog("========================================");
    MMLog("=== MOUSECAPE HELPER DAEMON STARTED ===");
    MMLog("========================================");

    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    MMLog("macOS version: %ld.%ld.%ld",
          (long)ver.majorVersion, (long)ver.minorVersion, (long)ver.patchVersion);
    MMLog("Process: %s (PID: %d)",
          [[[NSProcessInfo processInfo] processName] UTF8String],
          [[NSProcessInfo processInfo] processIdentifier]);
    MMLog("User: %s", NSUserName().UTF8String);
    MMLog("Home: %s", NSHomeDirectory().UTF8String);

    // Log environment variables
    MMLog("--- Environment Variables ---");
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    for (NSString *key in @[@"USER", @"HOME", @"DISPLAY", @"XPC_SERVICE_NAME"]) {
        MMLog("  %s = %s", key.UTF8String, [env[key] UTF8String] ?: "(null)");
    }

    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    if (!store) {
        MMLog(BOLD RED "Failed to create SCDynamicStore — session monitor unavailable" RESET);
        goto enter_runloop;
    }

    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    if (!key) {
        MMLog(BOLD RED "Failed to create console user key — session monitor unavailable" RESET);
        CFRelease(store);
        goto enter_runloop;
    }

    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    if (!keys) {
        MMLog(BOLD RED "Failed to create key array — session monitor unavailable" RESET);
        CFRelease(key);
        CFRelease(store);
        goto enter_runloop;
    }

    {
        Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
        if (!success) {
            MMLog(BOLD RED "Failed to set notification keys — session monitor unavailable" RESET);
            CFRelease(keys);
            CFRelease(key);
            CFRelease(store);
            goto enter_runloop;
        }
        CFRelease(keys);
        CFRelease(key);
    }

    NSApplicationLoad();
    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);

    {
        CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
        if (!rls) {
            MMLog(BOLD RED "Failed to create run loop source — session monitor unavailable" RESET);
            CFRelease(store);
            goto enter_runloop;
        }

        // Check CGS Connection
        MMLog("--- Checking CGS Connection ---");
        CGSConnectionID cid = CGSMainConnectionID();
        MMLog("CGSMainConnectionID: %d", cid);

        // Apply the cape for the user on load (if configured)
        MMLog("--- Initial Cape Check ---");
        NSString *initialCapePath = appliedCapePathForUser(NSUserName());
        MMLog("Cape path: %s", initialCapePath ? initialCapePath.UTF8String : "(none)");
        if (initialCapePath) {
            MMLog("--- Applying initial cape ---");
            BOOL applySuccess = applyCapeAtPath(initialCapePath);
            MMLog("Initial apply result: %s", applySuccess ? "SUCCESS" : "FAILED");
        } else {
            MMLog("No cape configured - refreshing system defaults at current scale");
            refreshSystemDefaultCursors();
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        MMLog("Entering run loop...");
        CFRunLoopRun();

        // Cleanup
        MMLog("Exiting run loop, cleaning up...");
        CFRunLoopSourceInvalidate(rls);
        CFRelease(rls);
    }

    // Cleanup display callback
    unregisterDisplayCallback();
    CFRelease(store);

#ifdef DEBUG
    MCLoggerClose();
#endif
    return;

enter_runloop:
    // Fallback: still enter run loop to keep the process alive, but without session monitoring
    MMLog(BOLD YELLOW "Entering run loop without session monitoring" RESET);
    CFRunLoopRun();
#ifdef DEBUG
    MCLoggerClose();
#endif
}

// Cleanup: remove display reconfiguration callback to prevent firing during teardown
static void unregisterDisplayCallback(void) {
    CGDisplayRemoveReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog("Display reconfiguration callback unregistered");
}

void startSessionMonitor(void) {
    MMLog("========================================");
    MMLog("=== SESSION MONITOR STARTED (in-app) ===");
    MMLog("========================================");

    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    if (!store) {
        MMLog(BOLD RED "Failed to create SCDynamicStore — session monitor unavailable" RESET);
        return;
    }

    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    if (!key) {
        MMLog(BOLD RED "Failed to create console user key — session monitor unavailable" RESET);
        CFRelease(store);
        return;
    }

    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    if (!keys) {
        MMLog(BOLD RED "Failed to create key array — session monitor unavailable" RESET);
        CFRelease(key);
        CFRelease(store);
        return;
    }

    {
        Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
        if (!success) {
            MMLog(BOLD RED "Failed to set notification keys — session monitor unavailable" RESET);
            CFRelease(keys);
            CFRelease(key);
            CFRelease(store);
            return;
        }
        CFRelease(keys);
        CFRelease(key);
    }

    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);

    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    if (!rls) {
        MMLog(BOLD RED "Failed to create run loop source — session monitor unavailable" RESET);
        unregisterDisplayCallback();
        CFRelease(store);
        return;
    }
    MMLog(BOLD CYAN "Listening for User changes" RESET);

    // Apply the cape for the user on load (if configured)
    NSString *initialCapePath = appliedCapePathForUser(NSUserName());
    if (initialCapePath) {
        BOOL applySuccess = applyCapeAtPath(initialCapePath);
        MMLog("Initial apply result: %s", applySuccess ? "SUCCESS" : "FAILED");
    } else {
        MMLog("No cape configured - refreshing system defaults at current scale");
        refreshSystemDefaultCursors();
    }
    g_sessionMonitorRLS = rls;
    CFRunLoopAddSource(CFRunLoopGetMain(), rls, kCFRunLoopDefaultMode);
    MMLog("Session monitor attached to main run loop (non-blocking)");

    // Intentionally not releasing store/rls — they must stay alive
    // for the lifetime of the app to keep the session monitor active.
}

void stopSessionMonitor(void) {
    MMLog("Stopping session monitor...");

    // Remove display reconfiguration callback to prevent firing during teardown
    unregisterDisplayCallback();

    // Remove run loop source to stop receiving session change notifications
    if (g_sessionMonitorRLS) {
        CFRunLoopSourceInvalidate(g_sessionMonitorRLS);
        g_sessionMonitorRLS = NULL;
        MMLog("Session monitor run loop source removed");
    }
}
