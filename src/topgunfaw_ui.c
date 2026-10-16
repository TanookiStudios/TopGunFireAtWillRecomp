/* The launcher's Game and About pages, and the settings file behind them.
 * The rows are registered with the runtime through psx_title_host.h. */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mod_plugins.h"        /* PSX_MOD_CONSTRUCTOR */
#include "psx_title_host.h"
#include "recomp_launcher.h"
#include "recomp_runtime_ui.h"
#include "topgunfaw_extras.h"

TgfawOptions g_tgfaw;

#define ROW(key, section, label, desc) { key, section, label, desc, \
                      RECOMP_RUNTIME_UI_BOOL, 0, 1, 1, NULL, 0, NULL }

static const RecompRuntimeUiItem kRows[] = {
    ROW("tgfaw.mute.music",  "Audio", "Mute music", "Silences the music and the movie soundtrack (the disc's own audio)."),
    ROW("tgfaw.mute.sfx",    "Audio", "Mute sound effects", "Silences engines, guns, missiles and radio beeps (all 24 of the PlayStation's sound voices)."),
    ROW("tgfaw.mute.reverb", "Audio", "Mute reverb", "Turns off the sound chip's echo, for a drier sound."),
    ROW("tgfaw.cheat.missiles", "Cheats", "Infinite missiles", "Firing a missile never uses one up."),
    ROW("tgfaw.cheat.ammo",     "Cheats", "Infinite gun ammo", "The cannon never runs dry."),
    ROW("tgfaw.cheat.hit",      "Cheats", "Can't be hit", "Your jet takes no damage."),
};
#define ROW_COUNT (sizeof kRows / sizeof kRows[0])

static int *field(const RecompRuntimeUiItem *it) {
    static const struct { const char *key; size_t off; } map[] = {
        { "tgfaw.mute.music",     offsetof(TgfawOptions, mute_music) },
        { "tgfaw.mute.sfx",       offsetof(TgfawOptions, mute_sfx) },
        { "tgfaw.mute.reverb",    offsetof(TgfawOptions, mute_reverb) },
        { "tgfaw.cheat.missiles", offsetof(TgfawOptions, inf_missiles) },
        { "tgfaw.cheat.ammo",     offsetof(TgfawOptions, inf_ammo) },
        { "tgfaw.cheat.hit",      offsetof(TgfawOptions, cant_be_hit) },
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
    for (size_t i = 0; i < ROW_COUNT; i++) fprintf(f, "%s=%d\n", kRows[i].key, *field(&kRows[i]));
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
        for (size_t i = 0; i < ROW_COUNT; i++)
            if (strcmp(line, kRows[i].key) == 0) *field(&kRows[i]) = atoi(eq + 1) ? 1 : 0;
    }
    fclose(f);
}

static int get_value(void *ctx, const RecompRuntimeUiItem *it, int *out) {
    (void)ctx;
    int *p = field(it);
    if (!p) return 0;
    *out = *p;
    return 1;
}

static int set_value(void *ctx, const RecompRuntimeUiItem *it, int v) {
    (void)ctx;
    int *p = field(it);
    if (!p) return 0;
    *p = v ? 1 : 0;
    TgfawApplyAudio();
    save();
    return 1;
}

static void save_cb(void *ctx) { (void)ctx; save(); }

static const RecompRuntimeUiCallbacks kCallbacks = {
    .context = NULL, .get_value = get_value, .set_value = set_value, .save = save_cb,
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
    }
    gi->game_items = kRows;
    gi->game_item_count = ROW_COUNT;
    gi->game_callbacks = &kCallbacks;
    gi->about_text = kAbout;
    gi->about_image = "maddie-signature.png";   /* assets/signature.png, staged by CMakeLists.txt */
    gi->about_link_url = "https://tanookistudios.com/SupportMe";
    gi->about_link_label = "Leave a Tip";
    gi->mods = NULL;                             /* no Mods page */
}

PSX_MOD_CONSTRUCTOR(tgfaw_register_launcher) {
    psx_title_set_launcher_hook(launcher_info);
}
