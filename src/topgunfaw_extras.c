/* Cheats and audio switches acting on the running game.
 * Every address here is proven in notes/ram-map.md. */
#include "topgunfaw_extras.h"

#include <stdint.h>
#include <stdlib.h>

#include "mod_plugins.h"
#include "psx_title_host.h"
#include "spu.h"

/* Weapon table: one 16-bit count per weapon type, 0xFFFF = not carried.
 * Standard missiles are the slot at 0x801CFECA. */
#define WEAPONS_FIRST 0x801CFEBCu
#define WEAPON_SLOTS  12
#define NOT_CARRIED   0xFFFFu
/* Lives, as the debrief shows them. */
#define LIVES         0x8019FE39u

void TgfawApplyAudio(void) {
    g_spu_host_mute = (g_tgfaw.mute_music ? SPU_HOST_MUTE_MUSIC : 0u) |
                      (g_tgfaw.mute_sfx ? SPU_HOST_MUTE_SFX : 0u);
}

/* The house cheat pattern: never hold a value from power-on (that can freeze
 * title screens); only undo a drop of exactly one, the moment it happens.
 * New missions and new games set these counts upward, which passes through. */
static uint16_t s_weapons[WEAPON_SLOTS];
static uint8_t s_lives;
static int s_seen;

static void cheats_vblank(void) {
    if (!psx_mod_game_started()) { s_seen = 0; return; }
    for (int i = 0; i < WEAPON_SLOTS; i++) {
        const uint32_t a = WEAPONS_FIRST + 2u * (uint32_t)i;
        uint16_t v = psx_mod_read_half(a);
        if (g_tgfaw.inf_missiles && s_seen && v != NOT_CARRIED && s_weapons[i] != NOT_CARRIED &&
            v + 1u == s_weapons[i]) {
            psx_mod_write_half(a, s_weapons[i]);
            v = s_weapons[i];
        }
        s_weapons[i] = v;
    }
    uint8_t lives = psx_mod_read_byte(LIVES);
    if (g_tgfaw.inf_lives && s_seen && lives + 1u == s_lives) {
        psx_mod_write_byte(LIVES, s_lives);
        lives = s_lives;
    }
    s_lives = lives;
    s_seen = 1;
}

PSX_MOD_CONSTRUCTOR(tgfaw_register_cheats) {
    psx_title_set_vblank_hook(cheats_vblank);
}

/* Test hook: TGFAW_MUTE=<bits> (1 music, 2 sound effects) and
 * TGFAW_CHEATS=<bits> (1 missiles, 2 lives) for headless runs, which have no
 * launcher to set the switches. */
PSX_MOD_CONSTRUCTOR(tgfaw_env_switches) {
    const char *e = getenv("TGFAW_MUTE");
    if (e && *e) {
        const unsigned bits = (unsigned)strtoul(e, NULL, 0);
        g_tgfaw.mute_music = (bits & 1u) != 0;
        g_tgfaw.mute_sfx = (bits & 2u) != 0;
        TgfawApplyAudio();
    }
    e = getenv("TGFAW_CHEATS");
    if (e && *e) {
        const unsigned bits = (unsigned)strtoul(e, NULL, 0);
        g_tgfaw.inf_missiles = (bits & 1u) != 0;
        g_tgfaw.inf_lives = (bits & 2u) != 0;
    }
}
