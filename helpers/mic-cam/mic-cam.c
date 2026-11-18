// mic-cam: is a microphone or a camera in use right now, and by which apps.
// Feeds the bar's privacy indicator. macOS still draws its own orange / green
// dot with the native menu bar hidden (menubar-alpha), but only as a few pixels
// in the screen corner, and it names no app without the menu bar's Control
// Center.
//
//   mic-cam                      print the state once, one "key value" per line:
//                                  mic 0|1
//                                  cam 0|1
//                                  app <name>      (one line per app recording sound)
//   mic-cam --watch CMD [ARG...] run CMD at start and every time that output
//                                changes; event-driven, idle in between
//
// Microphone: CoreAudio's process objects (macOS 14.2+), per process, through
// kAudioProcessPropertyIsRunningInput. The device-level "running somewhere"
// flag is not enough: AirPods or EarPods are one device with input AND output,
// so playing music would light the mic.
// Camera: CoreMediaIO, kCMIODevicePropertyDeviceIsRunningSomewhere. Device
// level only: no public API says which app has the camera.
// Neither needs a TCC grant: both read metadata and never capture anything.
//
// App names: the outermost "X.app" in the path of the process's RESPONSIBLE
// process, so a browser tab reads "Google Chrome" (not its helper) and Safari
// "Safari" (not com.apple.WebKit.GPU). responsibility_get_pid_responsible_for_pid
// is private, so it is looked up with dlsym and skipped if it ever goes away.
//
// Part of MinBar (GPL-3.0). `--watch` runs as the launchd agent `minbar setup`
// installs and triggers the bar's mic_cam_change event.
#include <CoreAudio/CoreAudio.h>
#include <CoreMediaIO/CMIOHardware.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <libproc.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

#define MAX_IDS 512
#define MAX_APPS 16
#define NAME_LEN 128

static char **cmd;   // --watch: the command to run on a change
static int watching; // listeners are only registered in --watch mode
static dispatch_queue_t q;
static void (^on_change)(void);

// Objects already carrying our listener (process objects / cameras come and go).
static AudioObjectID audio_seen[MAX_IDS];
static UInt32 n_audio_seen;
static CMIOObjectID cam_seen[MAX_IDS];
static UInt32 n_cam_seen;

static int seen(const UInt32 *list, UInt32 n, UInt32 id) {
  for (UInt32 i = 0; i < n; i++)
    if (list[i] == id) return 1;
  return 0;
}

static const AudioObjectPropertyAddress PROCESSES = {
    kAudioHardwarePropertyProcessObjectList, kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain};
static const AudioObjectPropertyAddress RUNNING_INPUT = {
    kAudioProcessPropertyIsRunningInput, kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain};
static const AudioObjectPropertyAddress PID = {
    kAudioProcessPropertyPID, kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain};
static const CMIOObjectPropertyAddress CAMERAS = {
    kCMIOHardwarePropertyDevices, kCMIOObjectPropertyScopeGlobal,
    kCMIOObjectPropertyElementMain};
static const CMIOObjectPropertyAddress CAMERA_RUNNING = {
    kCMIODevicePropertyDeviceIsRunningSomewhere, kCMIOObjectPropertyScopeWildcard,
    kCMIOObjectPropertyElementWildcard};

static pid_t responsible(pid_t pid) {
  static pid_t (*fn)(pid_t);
  static int looked;
  if (!looked) {
    fn = (pid_t(*)(pid_t))dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
    looked = 1;
  }
  pid_t r = fn ? fn(pid) : -1;
  return r > 0 ? r : pid;
}

static void app_name(pid_t pid, char *out, size_t len) {
  char path[PROC_PIDPATHINFO_MAXSIZE];
  if (proc_pidpath(responsible(pid), path, sizeof path) <= 0 &&
      proc_pidpath(pid, path, sizeof path) <= 0) {
    snprintf(out, len, "pid %d", pid);
    return;
  }
  char *app = strstr(path, ".app/"); // the first one is the outermost bundle
  if (app) *app = '\0';
  char *base = strrchr(path, '/');
  snprintf(out, len, "%s", base ? base + 1 : path);
}

// Who is recording sound: names of the apps whose processes run input.
static int scan_mic(char apps[MAX_APPS][NAME_LEN]) {
  AudioObjectID ids[MAX_IDS];
  UInt32 size = sizeof ids;
  if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &PROCESSES, 0, NULL, &size, ids))
    return 0;
  UInt32 n = size / sizeof(AudioObjectID);
  int napps = 0;
  for (UInt32 i = 0; i < n; i++) {
    if (watching && !seen(audio_seen, n_audio_seen, ids[i]) &&
        AudioObjectAddPropertyListenerBlock(ids[i], &RUNNING_INPUT, q,
                                            ^(UInt32 c, const AudioObjectPropertyAddress *a) {
                                              (void)c, (void)a;
                                              on_change();
                                            }) == noErr &&
        n_audio_seen < MAX_IDS)
      audio_seen[n_audio_seen++] = ids[i];

    UInt32 on = 0, sz = sizeof on;
    pid_t pid = 0;
    UInt32 psz = sizeof pid;
    if (AudioObjectGetPropertyData(ids[i], &RUNNING_INPUT, 0, NULL, &sz, &on) || !on) continue;
    if (AudioObjectGetPropertyData(ids[i], &PID, 0, NULL, &psz, &pid) || pid == getpid()) continue;

    char name[NAME_LEN];
    app_name(pid, name, sizeof name);
    int dup = 0;
    for (int j = 0; j < napps; j++)
      if (!strcmp(apps[j], name)) dup = 1;
    if (!dup && napps < MAX_APPS) snprintf(apps[napps++], NAME_LEN, "%s", name);
  }
  // Process objects that are gone took their listeners with them.
  if (watching) {
    UInt32 kept = 0;
    for (UInt32 i = 0; i < n_audio_seen; i++)
      if (seen(ids, n, audio_seen[i])) audio_seen[kept++] = audio_seen[i];
    n_audio_seen = kept;
  }
  return napps;
}

static int scan_cam(void) {
  CMIOObjectID ids[MAX_IDS];
  UInt32 used = 0;
  if (CMIOObjectGetPropertyData(kCMIOObjectSystemObject, &CAMERAS, 0, NULL, sizeof ids, &used, ids))
    return 0;
  UInt32 n = used / sizeof(CMIOObjectID);
  int any = 0;
  for (UInt32 i = 0; i < n; i++) {
    if (watching && !seen(cam_seen, n_cam_seen, ids[i]) &&
        CMIOObjectAddPropertyListenerBlock(ids[i], &CAMERA_RUNNING, q,
                                           ^(UInt32 c, const CMIOObjectPropertyAddress *a) {
                                             (void)c, (void)a;
                                             on_change();
                                           }) == noErr &&
        n_cam_seen < MAX_IDS)
      cam_seen[n_cam_seen++] = ids[i];

    UInt32 on = 0, sz = 0;
    if (!CMIOObjectGetPropertyData(ids[i], &CAMERA_RUNNING, 0, NULL, sizeof on, &sz, &on) && on)
      any = 1;
  }
  if (watching) {
    UInt32 kept = 0;
    for (UInt32 i = 0; i < n_cam_seen; i++)
      if (seen(ids, n, cam_seen[i])) cam_seen[kept++] = cam_seen[i];
    n_cam_seen = kept;
  }
  return any;
}

// The whole state as the text `mic-cam` prints; --watch compares these.
static void state(char *out, size_t len) {
  char apps[MAX_APPS][NAME_LEN];
  int napps = scan_mic(apps);
  int n = snprintf(out, len, "mic %d\ncam %d\n", napps > 0, scan_cam());
  for (int i = 0; i < napps && n > 0 && (size_t)n < len; i++)
    n += snprintf(out + n, len - n, "app %s\n", apps[i]);
}

static void update(void) {
  static char last[4096];
  char now[sizeof last];
  state(now, sizeof now);
  if (!strcmp(now, last)) return;
  memcpy(last, now, sizeof last);
  pid_t pid;
  if (posix_spawnp(&pid, cmd[0], NULL, NULL, cmd, environ))
    perror(cmd[0]);
}

int main(int argc, char **argv) {
  if (argc == 1) {
    char now[4096];
    state(now, sizeof now);
    fputs(now, stdout);
    return 0;
  }
  if (argc < 3 || strcmp(argv[1], "--watch")) {
    fprintf(stderr, "usage: mic-cam                  print mic/cam state\n"
                    "       mic-cam --watch CMD...   run CMD whenever it changes\n");
    return 64;
  }

  cmd = argv + 2;
  watching = 1;
  signal(SIGCHLD, SIG_IGN); // CMD is fire-and-forget: let the kernel reap it
  q = dispatch_get_main_queue();
  // A process starting to record fires several notifications in a row (it
  // registers, then starts input); coalesce them into one rescan.
  static int pending;
  on_change = ^{
    if (pending) return;
    pending = 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), q, ^{
      pending = 0;
      update();
    });
  };
  AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &PROCESSES, q,
                                      ^(UInt32 c, const AudioObjectPropertyAddress *a) {
                                        (void)c, (void)a;
                                        on_change();
                                      });
  CMIOObjectAddPropertyListenerBlock(kCMIOObjectSystemObject, &CAMERAS, q,
                                     ^(UInt32 c, const CMIOObjectPropertyAddress *a) {
                                       (void)c, (void)a;
                                       on_change();
                                     });
  update();
  dispatch_main();
}
