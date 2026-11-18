// menus — the bar's Accessibility helper: lists the frontmost app's menus
// (`-l`), clicks one (`-s N`) or a menu extra by alias (`-s Owner,Name`), and
// types a key with modifiers (`-k CODE MODS`).
//
// Originally from Felix Kratz's dotfiles (github.com/FelixKratz/dotfiles,
// .config/sketchybar/helpers/menus/menus.c), GPL-3.0. Modified for MinBar:
// added post_one / post_key and the `-k` option (2026). Distributed under the
// GNU General Public License v3.0, see LICENSE.

#include <Carbon/Carbon.h>

void ax_init() {
  const void *keys[] = { kAXTrustedCheckOptionPrompt };
  const void *values[] = { kCFBooleanTrue };

  CFDictionaryRef options;
  options = CFDictionaryCreate(kCFAllocatorDefault,
                               keys,
                               values,
                               sizeof(keys) / sizeof(*keys),
                               &kCFCopyStringDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks     );

  bool trusted = AXIsProcessTrustedWithOptions(options);
  CFRelease(options);
  if (!trusted) exit(1);
}

void ax_perform_click(AXUIElementRef element) {
  if (!element) return;
  AXUIElementPerformAction(element, kAXCancelAction);
  usleep(150000);
  AXUIElementPerformAction(element, kAXPressAction);
}

CFStringRef ax_get_title(AXUIElementRef element) {
  CFTypeRef title = NULL;
  AXError error = AXUIElementCopyAttributeValue(element,
                                                kAXTitleAttribute,
                                                &title            );

  if (error != kAXErrorSuccess) return NULL;
  return title;
}

void ax_select_menu_option(AXUIElementRef app, int id) {
  AXUIElementRef menubars_ref = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(app,
                                                kAXMenuBarAttribute,
                                                (CFTypeRef*)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(menubars_ref,
                                          kAXVisibleChildrenAttribute,
                                          (CFTypeRef*)&children_ref   );

    if (error == kAXErrorSuccess) {
      uint32_t count = CFArrayGetCount(children_ref);
      if (id < count) {
        AXUIElementRef item = CFArrayGetValueAtIndex(children_ref, id);
        ax_perform_click(item);
      }
      if (children_ref) CFRelease(children_ref);
    }
    if (menubars_ref) CFRelease(menubars_ref);
  }
}

void ax_print_menu_options(AXUIElementRef app) {
  AXUIElementRef menubars_ref = NULL;
  CFTypeRef menubar = NULL;
  CFArrayRef children_ref = NULL;

  AXError error = AXUIElementCopyAttributeValue(app,
                                                kAXMenuBarAttribute,
                                                (CFTypeRef*)&menubars_ref);
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(menubars_ref,
                                          kAXVisibleChildrenAttribute,
                                          (CFTypeRef*)&children_ref   );

    if (error == kAXErrorSuccess) {
      uint32_t count = CFArrayGetCount(children_ref);

      for (int i = 1; i < count; i++) {
        AXUIElementRef item = CFArrayGetValueAtIndex(children_ref, i);
        CFTypeRef title = ax_get_title(item);

        if (title) {
          uint32_t buffer_len = 2*CFStringGetLength(title);
          char buffer[2*CFStringGetLength(title)];
          CFStringGetCString(title, buffer, buffer_len, kCFStringEncodingUTF8);
          printf("%s\n", buffer);
          CFRelease(title);
        }
      }
    }
    if (menubars_ref) CFRelease(menubars_ref);
    if (children_ref) CFRelease(children_ref);
  }
}

AXUIElementRef ax_get_extra_menu_item(char* alias) {
  pid_t pid = 0;
  CGRect bounds = CGRectNull;
  CFArrayRef window_list = CGWindowListCopyWindowInfo(kCGWindowListOptionAll,
                                                      kCGNullWindowID        );
  char owner_buffer[256];
  char name_buffer[256];
  char buffer[512];
  int window_count = CFArrayGetCount(window_list);
  for (int i = 0; i < window_count; ++i) {
    CFDictionaryRef dictionary = CFArrayGetValueAtIndex(window_list, i);
    if (!dictionary) continue;

    CFStringRef owner_ref = CFDictionaryGetValue(dictionary,
                                                 kCGWindowOwnerName);

    CFNumberRef owner_pid_ref = CFDictionaryGetValue(dictionary,
                                                     kCGWindowOwnerPID);

    CFStringRef name_ref = CFDictionaryGetValue(dictionary, kCGWindowName);
    CFNumberRef layer_ref = CFDictionaryGetValue(dictionary, kCGWindowLayer);
    CFDictionaryRef bounds_ref = CFDictionaryGetValue(dictionary,
                                                      kCGWindowBounds);

    if (!name_ref || !owner_ref || !owner_pid_ref || !layer_ref || !bounds_ref)
      continue;

    long long int layer = 0;
    CFNumberGetValue(layer_ref, CFNumberGetType(layer_ref), &layer);
    uint64_t owner_pid = 0;
    CFNumberGetValue(owner_pid_ref,
                     CFNumberGetType(owner_pid_ref),
                     &owner_pid                     );

    if (layer != 0x19) continue;
    bounds = CGRectNull;
    if (!CGRectMakeWithDictionaryRepresentation(bounds_ref, &bounds)) continue;
    CFStringGetCString(owner_ref,
                       owner_buffer,
                       sizeof(owner_buffer),
                       kCFStringEncodingUTF8);

    CFStringGetCString(name_ref,
                       name_buffer,
                       sizeof(name_buffer),
                       kCFStringEncodingUTF8);
    snprintf(buffer, sizeof(buffer), "%s,%s", owner_buffer, name_buffer);

    if (strcmp(buffer, alias) == 0) {
      pid = owner_pid;
      break;
    }
  }
  CFRelease(window_list);
  if (!pid) return NULL;

  AXUIElementRef app = AXUIElementCreateApplication(pid);
  if (!app) return NULL;
  AXUIElementRef result = NULL;
  CFTypeRef extras = NULL;
  CFArrayRef children_ref = NULL;
  AXError error = AXUIElementCopyAttributeValue(app,
                                                kAXExtrasMenuBarAttribute,
                                                &extras                   );
  if (error == kAXErrorSuccess) {
    error = AXUIElementCopyAttributeValue(extras,
                                          kAXVisibleChildrenAttribute,
                                          (CFTypeRef*)&children_ref   );

    if (error == kAXErrorSuccess) {
      uint32_t count = CFArrayGetCount(children_ref);
      for (uint32_t i = 0; i < count; i++) {
        AXUIElementRef item = CFArrayGetValueAtIndex(children_ref, i);
        CFTypeRef position_ref = NULL;
        CFTypeRef size_ref = NULL;
        AXUIElementCopyAttributeValue(item, kAXPositionAttribute,
                                            &position_ref        );
        AXUIElementCopyAttributeValue(item, kAXSizeAttribute,
                                            &size_ref        );
        if (!position_ref || !size_ref) continue;

        CGPoint position = CGPointZero;
        AXValueGetValue(position_ref, kAXValueCGPointType, &position);
        CGSize size = CGSizeZero;
        AXValueGetValue(size_ref, kAXValueCGSizeType, &size);
        CFRelease(position_ref);
        CFRelease(size_ref);
        // The offset is exactly 8 on macOS Sonoma...
        // printf("%f %f\n", position.x, bounds.origin.x);
        if (error == kAXErrorSuccess
            && fabs(position.x - bounds.origin.x) <= 10) {
          result = item;
          break;
        }
      }
    }
  }

  CFRelease(app);
  return result;
}

extern int SLSMainConnectionID();
extern void SLSSetMenuBarVisibilityOverrideOnDisplay(int cid, int did, bool enabled);
extern void SLSSetMenuBarVisibilityOverrideOnDisplay(int cid, int did, bool enabled);
extern void SLSSetMenuBarInsetAndAlpha(int cid, double u1, double u2, float alpha);
void ax_select_menu_extra(char* alias) {
  AXUIElementRef item = ax_get_extra_menu_item(alias);
  if (!item) return;
  SLSSetMenuBarInsetAndAlpha(SLSMainConnectionID(), 0, 1, 0.0);
  SLSSetMenuBarVisibilityOverrideOnDisplay(SLSMainConnectionID(), 0, true);
  SLSSetMenuBarInsetAndAlpha(SLSMainConnectionID(), 0, 1, 0.0);
  ax_perform_click(item);
  SLSSetMenuBarVisibilityOverrideOnDisplay(SLSMainConnectionID(), 0, false);
  SLSSetMenuBarInsetAndAlpha(SLSMainConnectionID(), 0, 1, 1.0);
  CFRelease(item);
}

extern void _SLPSGetFrontProcess(ProcessSerialNumber* psn);
extern void SLSGetConnectionIDForPSN(int cid, ProcessSerialNumber* psn, int* cid_out);
extern void SLSConnectionGetPID(int cid, pid_t* pid_out);
AXUIElementRef ax_get_front_app() {
  ProcessSerialNumber psn;
  _SLPSGetFrontProcess(&psn);
  int target_cid;
  SLSGetConnectionIDForPSN(SLSMainConnectionID(), &psn, &target_cid);

  pid_t pid;
  SLSConnectionGetPID(target_cid, &pid);
  return AXUIElementCreateApplication(pid);
}

// `-k KEYCODE [MODS]`: type one key, MODS a comma list of ctrl, alt, cmd and
// shift (`-k 45 ctrl,alt,cmd`). For what the bar opens through a system
// shortcut because no AX element does it: Notification Center, whose clock
// menu extra, pressed with the native bar hidden, shows the panel for under
// half a second (the bell in sketchybarrc). The modifiers go down and up as
// keys of their own, like a keyboard: posted only as flags on the key, the
// system shortcut matched about one press in four.
static void post_one(CGEventSourceRef source, CGKeyCode key, bool down, CGEventFlags flags) {
  CGEventRef event = CGEventCreateKeyboardEvent(source, key, down);
  if (!event) return;
  CGEventSetFlags(event, flags);
  CGEventPost(kCGHIDEventTap, event);
  CFRelease(event);
  usleep(8000);
}

int post_key(const char *code, const char *mods) {
  int keycode = 0;
  if (sscanf(code, "%d", &keycode) != 1 || keycode < 0 || keycode > 127) return 2;
  // kVK_Control, kVK_Option, kVK_Command, kVK_Shift, in press order.
  struct { const char *name; CGKeyCode key; CGEventFlags flag; } all[] = {
    { "ctrl",  59, kCGEventFlagMaskControl   },
    { "alt",   58, kCGEventFlagMaskAlternate },
    { "cmd",   55, kCGEventFlagMaskCommand   },
    { "shift", 56, kCGEventFlagMaskShift     },
  };
  int held[4], n = 0;
  for (int i = 0; i < 4; i++)
    if (mods && strstr(mods, all[i].name)) held[n++] = i;

  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
  CGEventFlags flags = 0;
  for (int i = 0; i < n; i++) {
    flags |= all[held[i]].flag;
    post_one(source, all[held[i]].key, true, flags);
  }
  post_one(source, (CGKeyCode)keycode, true, flags);
  post_one(source, (CGKeyCode)keycode, false, flags);
  for (int i = n - 1; i >= 0; i--) {
    flags &= ~all[held[i]].flag;
    post_one(source, all[held[i]].key, false, flags);
  }
  if (source) CFRelease(source);
  return 0;
}

int main (int argc, char **argv) {
  if (argc == 1) {
    printf("Usage: %s [-l | -s id/alias | -k keycode [mods] ]\n", argv[0]);
    exit(0);
  }
  ax_init();
  if ((argc == 3 || argc == 4) && strcmp(argv[1], "-k") == 0) {
    return post_key(argv[2], argc == 4 ? argv[3] : NULL);
  } else if (strcmp(argv[1], "-l") == 0) {
    AXUIElementRef app = ax_get_front_app();
    if (!app) return 1;
    ax_print_menu_options(app);
    CFRelease(app);
  } else if (argc == 3 && strcmp(argv[1], "-s") == 0) {
    int id = 0;
    if (sscanf(argv[2], "%d", &id) == 1) {
      AXUIElementRef app = ax_get_front_app();
      if (!app) return 1;
      ax_select_menu_option(app, id);
      CFRelease(app);
    } else ax_select_menu_extra(argv[2]);
  }
  return 0;
}
