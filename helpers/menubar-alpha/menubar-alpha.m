// menubar-alpha — keep the native macOS menu bar at a fixed alpha for as long
// as this process lives. Same SkyLight call yabai's `menubar_opacity` makes
// (window_manager.c: SLSSetMenuBarInsetAndAlpha); no scripting addition and no
// SIP change needed.
//
// The setting is scoped to the calling WindowServer connection and reverts the
// moment that connection closes, so this must run as a daemon (launchd
// KeepAlive), not as a one-shot. At alpha 0 the menu bar also stops hit-testing,
// so it never slides in on hover — the permanent hide macOS itself won't offer
// (_HIHideMenuBar only auto-hides).
//
// Like yabai, the bar is restored to 1.0 while a native-fullscreen space is
// active on the menu-bar display (macOS does this on its own on entering
// fullscreen; fullscreen apps rely on the hover reveal to reach their menus)
// and hidden again on leaving it.
//
// Usage: menubar-alpha [-v] [alpha]   (default 0.0; -v logs each change)
#import <Cocoa/Cocoa.h>
#include <signal.h>

extern int SLSMainConnectionID(void);
extern CGError SLSSetMenuBarInsetAndAlpha(int cid, double unused1, double unused2, float alpha);
extern CFStringRef SLSCopyActiveMenuBarDisplayIdentifier(int cid);
extern uint64_t SLSManagedDisplayGetCurrentSpace(int cid, CFStringRef uuid);
extern int SLSSpaceGetType(int cid, uint64_t sid);

static int g_cid;
static float g_alpha;
static bool g_verbose;

// Native fullscreen = space type 4 (yabai's space_is_fullscreen).
static bool menubar_display_is_fullscreen(void) {
    CFStringRef uuid = SLSCopyActiveMenuBarDisplayIdentifier(g_cid);
    if (!uuid) return false;
    uint64_t sid = SLSManagedDisplayGetCurrentSpace(g_cid, uuid);
    CFRelease(uuid);
    return SLSSpaceGetType(g_cid, sid) == 4;
}

static void apply(const char *why) {
    float a = menubar_display_is_fullscreen() ? 1.0f : g_alpha;
    CGError err = SLSSetMenuBarInsetAndAlpha(g_cid, 0, 1, a);
    if (g_verbose || err != kCGErrorSuccess)
        fprintf(stderr, "menubar-alpha: %s -> alpha %.2f (err %d)\n", why, a, err);
}

// Closing the connection restores the bar anyway; do it explicitly so a
// `launchctl stop` leaves no window where the bar is hidden with nobody owning it.
static void restore_and_exit(int sig) {
    SLSSetMenuBarInsetAndAlpha(g_cid, 0, 1, 1.0f);
    _exit(0);
}

int main(int argc, char **argv) {
    g_alpha = 0.0f;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0) { g_verbose = true; continue; }
        g_alpha = strtof(argv[i], NULL);
        if (g_alpha < 0.0f || g_alpha > 1.0f) {
            fprintf(stderr, "usage: %s [-v] [alpha 0.0-1.0]\n", argv[0]);
            return 2;
        }
    }
    g_cid = SLSMainConnectionID();
    signal(SIGTERM, restore_and_exit);
    signal(SIGINT, restore_and_exit);
    apply("start");

    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification object:nil queue:nil
                usingBlock:^(NSNotification *n) { apply("space changed"); }];
    [nc addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:nil
                usingBlock:^(NSNotification *n) { apply("woke"); }];
    [nc addObserverForName:NSWorkspaceScreensDidWakeNotification object:nil queue:nil
                usingBlock:^(NSNotification *n) { apply("screens woke"); }];

    // NSWorkspace only delivers space/wake notifications to processes registered
    // with the window server as an application, so spin up NSApplication —
    // Prohibited policy keeps it out of the Dock and the Cmd-Tab switcher.
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    [NSApp run];
    return 0;
}
