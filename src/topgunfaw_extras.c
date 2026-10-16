/* Cheats and audio switches acting on the running game. */
#include "topgunfaw_extras.h"

#include "spu.h"

void TgfawApplyAudio(void) {
    g_spu_host_mute = (g_tgfaw.mute_music ? SPU_HOST_MUTE_MUSIC : 0u) |
                      (g_tgfaw.mute_sfx ? SPU_HOST_MUTE_SFX : 0u);
}

/* Test hook: TGFAW_MUTE=<bits> (1 music, 2 sound effects) for
 * headless runs, which have no launcher to set the switches. */
#include <stdlib.h>
#include "mod_plugins.h"
PSX_MOD_CONSTRUCTOR(tgfaw_env_mute) {
    const char *e = getenv("TGFAW_MUTE");
    if (!e || !*e) return;
    const unsigned bits = (unsigned)strtoul(e, NULL, 0);
    g_tgfaw.mute_music = (bits & 1u) != 0;
    g_tgfaw.mute_sfx = (bits & 2u) != 0;
    TgfawApplyAudio();
}
