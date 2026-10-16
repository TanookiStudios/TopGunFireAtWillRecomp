/* The launcher's Game and About pages, and the settings file behind them.
 * The rows are registered with the runtime through psx_title_host.h. */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gpu_gl_renderer.h"    /* gl_renderer_set_integer_scale */
#include "host_osd.h"           /* host_volume_get/set */
#include "mod_plugins.h"        /* PSX_MOD_CONSTRUCTOR */
#include "savestate.h"
#include "psx_title_host.h"
#include "recomp_launcher.h"
#include "recomp_runtime_ui.h"
#include "topgunfaw_extras.h"

TgfawOptions g_tgfaw = { .integer_scale = 1 };   /* house style: crisp by default */

/* The game's own mission ranges (read from its "LOADING ..." code). */
static const char *const kMissions[32] = {
    "Off (start at Miramar 1)", "Miramar 2", "Miramar 3", "Miramar 4", "Miramar 5", "Miramar 6",
    "Cuba 1", "Cuba 2", "Cuba 3", "Cuba 4", "Cuba 5", "Cuba 6", "Cuba 7",
    "Korea 1", "Korea 2", "Korea 3", "Korea 4", "Korea 5", "Korea 6", "Korea 7", "Korea 8",
    "Korea 9", "Korea 10",
    "Libya 1", "Libya 2", "Libya 3", "Libya 4", "Libya 5", "Libya 6", "Libya 7", "Libya 8",
    "Bonus mission",
};

#define ROW(key, section, label, desc) { key, section, label, desc, \
                      RECOMP_RUNTIME_UI_BOOL, 0, 1, 1, NULL, 0, NULL }

static const RecompRuntimeUiItem kRows[] = {
    ROW("tgfaw.integer_scale", "Display", "Integer scaling",
        "On: the picture grows in whole steps, so every line is the same thickness. Off: it fills the window."),
    ROW("tgfaw.mute.music",  "Audio", "Mute music", "Silences the music and the movie soundtrack (the disc's own audio)."),
    ROW("tgfaw.mute.sfx",    "Audio", "Mute sound effects", "Silences engines, guns, missiles and radio beeps (all 24 of the PlayStation's sound voices)."),
    ROW("tgfaw.cheat.missiles", "Cheats", "Infinite missiles", "Firing a missile never uses one up."),
    ROW("tgfaw.cheat.lives",    "Cheats", "Infinite lives", "Getting shot down or crashing never costs a life."),
    { "tgfaw.cheat.start", "Cheats", "Start at mission", "New games begin at this mission.",
      RECOMP_RUNTIME_UI_CHOICE, 0, 31, 1, kMissions, 32, NULL },
    { "tgfaw.cheat.skip", "Cheats", "Skip to the next mission",
      "Moves you on one mission. Then pause and choose Abort Mission: the next one loads and no life is lost.",
      RECOMP_RUNTIME_UI_ACTION, 0, 0, 0, NULL, 0, NULL },
};
#define ROW_COUNT (sizeof kRows / sizeof kRows[0])

/* Rows only the Esc menu shows: reminders of the keys (greyed out, they
 * are information) -- the same list as the other Tanooki ports. */
#define HINT(key, label, desc) { key, "Controls", label, desc, \
                      RECOMP_RUNTIME_UI_ACTION, 0, 0, 0, NULL, 0, NULL }
static const RecompRuntimeUiItem kMenuRows[] = {
    HINT("tgfaw.hint.menu", "Open this menu",
         "Esc on the keyboard. On a controller: the Guide / Home button, or Select + left stick click."),
    HINT("tgfaw.hint.state", "Quick save and load", "F7 opens the save-state slots."),
    HINT("tgfaw.hint.fullscreen", "Fullscreen", "Alt + Enter."),
    HINT("tgfaw.hint.turbo", "Fast forward", "Hold Tab (F9 switches it on and off)."),
    HINT("tgfaw.hint.volume", "Volume", "Keypad + and Keypad -."),
};
#define MENU_ROW_COUNT (sizeof kMenuRows / sizeof kMenuRows[0])

static int s_slot = 1;   /* the Esc menu's state slot, 1-10 */

static int is_key(const RecompRuntimeUiItem *it, const char *key) { return it && it->key && !strcmp(it->key, key); }

static int *field(const RecompRuntimeUiItem *it) {
    static const struct { const char *key; size_t off; } map[] = {
        { "tgfaw.integer_scale",  offsetof(TgfawOptions, integer_scale) },
        { RECOMP_RUNTIME_UI_KEY_INTEGER_SCALE, offsetof(TgfawOptions, integer_scale) },
        { "tgfaw.mute.music",     offsetof(TgfawOptions, mute_music) },
        { "tgfaw.mute.sfx",       offsetof(TgfawOptions, mute_sfx) },
        { "tgfaw.cheat.missiles", offsetof(TgfawOptions, inf_missiles) },
        { "tgfaw.cheat.lives",    offsetof(TgfawOptions, inf_lives) },
        { "tgfaw.cheat.start",    offsetof(TgfawOptions, start_mission) },   /* the mission itself, 0 = off */
    };
    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++)
        if (strcmp(it->key, map[i].key) == 0) return (int *)((char *)&g_tgfaw + map[i].off);
    return NULL;
}

/* topgunfaw.ini sits beside the runtime's own config file (the settings
 * folder), so it moves wherever the runtime's settings go. */
static char s_ini[1024];

static void save(void) {
    if (!s_ini[0]) return;
    FILE *f = fopen(s_ini, "w");
    if (!f) return;
    for (size_t i = 0; i < ROW_COUNT; i++) {
        const int *p = field(&kRows[i]);
        if (p) fprintf(f, "%s=%d\n", kRows[i].key, *p);   /* action rows have no value */
    }
    fclose(f);
}

static void load(void) {
    FILE *f = fopen(s_ini, "r");
    if (!f) return;
    char line[256];
    while (fgets(line, sizeof line, f)) {
        char *eq = strchr(line, '=');
        if (!eq) continue;
        *eq = 0;
        for (size_t i = 0; i < ROW_COUNT; i++) {
            int *p = field(&kRows[i]);
            if (!p || strcmp(line, kRows[i].key) != 0) continue;
            const int v = atoi(eq + 1);
            if (kRows[i].type == RECOMP_RUNTIME_UI_BOOL) *p = v ? 1 : 0;
            else *p = v >= 2 && v <= 32 ? v : 0;   /* start mission */
        }
    }
    fclose(f);
}

static int get_value(void *ctx, const RecompRuntimeUiItem *it, int *out) {
    (void)ctx;
    if (is_key(it, "tgfaw.cheat.start")) { *out = g_tgfaw.start_mission > 1 ? g_tgfaw.start_mission - 1 : 0; return 1; }
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_VOLUME)) { *out = host_volume_get(); return 1; }
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_STATE_SLOT)) { *out = s_slot; return 1; }
    int *p = field(it);
    if (!p) return 0;
    *out = *p;
    return 1;
}

static int set_value(void *ctx, const RecompRuntimeUiItem *it, int v) {
    (void)ctx;
    if (is_key(it, "tgfaw.cheat.start")) {
        g_tgfaw.start_mission = v >= 1 && v <= 31 ? v + 1 : 0;
        save();
        return 1;
    }
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_VOLUME)) { host_volume_set(v); return 1; }
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_STATE_SLOT)) { s_slot = v < 1 ? 1 : (v > 10 ? 10 : v); return 1; }
    int *p = field(it);
    if (!p) return 0;
    *p = v ? 1 : 0;
    TgfawApplyAudio();
    gl_renderer_set_integer_scale(g_tgfaw.integer_scale);
    save();
    return 1;
}

static void save_cb(void *ctx) { (void)ctx; save(); }

static int run_action(void *ctx, const RecompRuntimeUiItem *it) {
    (void)ctx;
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_SAVE_STATE)) return savestate_request_save(s_slot - 1);
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_LOAD_STATE)) return savestate_request_load(s_slot - 1);
    if (is_key(it, RECOMP_RUNTIME_UI_KEY_RESET)) { psx_title_request_reset(); return 1; }
    if (is_key(it, "tgfaw.cheat.skip")) return TgfawSkipMission();
    return 0;
}

static int is_enabled(void *ctx, const RecompRuntimeUiItem *it) {
    (void)ctx;
    return !(it && it->key && !strncmp(it->key, "tgfaw.hint.", 11));   /* information rows */
}

static const RecompRuntimeUiCallbacks kCallbacks = {
    .context = NULL, .get_value = get_value, .set_value = set_value,
    .run_action = run_action, .is_enabled = is_enabled, .save = save_cb,
};

static const char kAbout[] =
    "Hi, I'm Maddie. I make apps and games on my own at Tanooki Studios.\n\n"
    "Top Gun: Fire at Will is a PlayStation dogfighting game I wanted to see on a modern computer, "
    "with a proper launcher, controllers that just work, and a few cheats for when a MiG is being mean.\n\n"
    "It's free, and it'll stay free. You bring your own copy of the game; nothing from the original disc "
    "ships with this. It isn't made by or affiliated with Spectrum HoloByte, Paramount Pictures or Sony.\n\n"
    "Making apps (including some decomps) is how I pay my bills. If this game brought you some nostalgia "
    "and you got shot down by the same MiG three times in a row, feel free to drop me a tiny tip. "
    "It really helps!";

static void launcher_info(RecompLauncherCGameInfo *gi) {
    if (!s_ini[0] && gi->config_path && gi->config_path[0]) {
        snprintf(s_ini, sizeof s_ini, "%s", gi->config_path);
        char *slash = strrchr(s_ini, '/');
        char *bslash = strrchr(s_ini, '\\');
        if (bslash > slash) slash = bslash;
        if (slash) slash[1] = 0; else s_ini[0] = 0;
        strncat(s_ini, "topgunfaw.ini", sizeof s_ini - strlen(s_ini) - 1);
        load();
        TgfawApplyAudio();
        gl_renderer_set_integer_scale(g_tgfaw.integer_scale);
    }
    gi->game_items = kRows;
    gi->game_item_count = ROW_COUNT;
    gi->game_callbacks = &kCallbacks;
    gi->menu_items = kMenuRows;
    gi->menu_item_count = MENU_ROW_COUNT;
    gi->about_text = kAbout;
    gi->about_image = "maddie-signature.png";   /* assets/signature.png, staged by CMakeLists.txt */
    gi->about_link_url = "https://tanookistudios.com/SupportMe";
    gi->about_link_label = "Leave a Tip";
    gi->mods = NULL;                             /* no Mods page */
}

PSX_MOD_CONSTRUCTOR(tgfaw_register_launcher) {
    psx_title_set_launcher_hook(launcher_info);
}
