/* Top Gun: Fire at Will -- the port's own options (Game page / Esc menu)
 * and the cheats that act on the running game. */
#ifndef TOPGUNFAW_EXTRAS_H
#define TOPGUNFAW_EXTRAS_H

typedef struct TgfawOptions {
    int integer_scale;   /* picture grows in whole 240-line steps */
    int mute_music;      /* CD audio and movie sound */
    int mute_sfx;        /* the 24 sound-chip voices */
    /* No reverb switch: the game never turns the sound chip's reverb on
     * (checked in the intro movie and mission 1), so it would do nothing. */
    int inf_missiles;
    int inf_lives;
    int cant_be_hit;
} TgfawOptions;

extern TgfawOptions g_tgfaw;

/* Push the audio switches into the engine (called after every change). */
void TgfawApplyAudio(void);

#endif
