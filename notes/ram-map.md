# Top Gun: Fire at Will (USA, SLUS-00032) — RAM map

PlayStation main RAM addresses (0x80000000 + offset). A value counts as found
only once changing it visibly changes the game. Tools: `tests/psx_tcp.py`
(routes, `ram`/`poke`/`shot` steps, needs `build-test/` with
`-DPSX_DEBUG_TOOLS=ON`), `tools/ram_find.py`, `tests/catch_event.py`.

## Found (proven)

| Address | Size | What | Proof |
|---|---|---|---|
| `0x801CFEBC`..`0x801CFED2` | 12 × u16 | Weapon table: one count per weapon type, `0xFFFF` = not carried. Same address in missions 1 and 2. | Mission 1 and 2 carry only Standard missiles (slot below); every other slot reads `0xFFFF`. |
| `0x801CFECA` | u16 | Standard missiles (the HUD's "50 STANDARD") | `ram_find`: 50 → 49 when Circle fired one (only match). `poke 0x801CFECA 7` → HUD "7 STANDARD"; firing one → "6 STANDARD" (`tests/route_cheat_missiles_poke.txt`). |
| `0x8019FE39` | u8 | Lives (the debrief's "LIVES: 3") | 3 through mission 2's flight, 2 after the crash (13 candidates). Wrote a different value into each candidate during mission 1; the debrief read **17**, the value written here. |
| `0x8019FE18` | u32 | Mission number, 1-based (1 = Miramar 1, 2 = Miramar 2) | The only 4-byte value that is 1 through mission 1 and 2 through mission 2. Written at a mission-1 debrief before Continue: 2 → the next briefing is mission 2's ("These drones are smaller and faster", "Loading Miramar 2"); 5 → a TARCAP briefing ("protect the boat") and an ocean mission. |
| `0x8019FE2C`, `0x8019FE32` | u8 | Kills this mission (both copies) | 0 → 1 → 2 as drones went down in mission 2; the debrief read "MISSION KILLS: 2". Not damage (poking them leaves the HUD silhouette green). |

## Cheats and their checks

| Cheat | How | Check |
|---|---|---|
| Infinite missiles | Each VBlank, a weapon slot that drops by exactly one is put back (slots reading `0xFFFF` are skipped) | `tests/route_cheat_missiles.txt`: three missiles fired in mission 1 → 47 with the cheat off, 50 with it on (`TGFAW_CHEATS=1`). |
| Infinite lives | Each VBlank, lives dropping by exactly one is put back | `tests/route_cheat_lives.txt`: aborting mission 1 from the pause menu costs a life. The debrief reads "LIVES: 2" with the cheat off and "LIVES: 3" with it on (`TGFAW_CHEATS=2`). |

Both run only after `psx_mod_game_started()` and never hold a value from
power-on; a new game or mission raising a count passes through.

## Game facts learned on the way

- Controls (the game's Options → Controller, Type 1): Circle missile,
  Triangle weapon select, R1 cycle targets, R2 throttle up, L2 throttle down,
  Up nose down, Down nose up, Left/Right roll, Select change view, Start pause.
  Square drops a flare, Cross fires the gun.
- No gun-ammo or flare counter exists: firing the gun for 240 frames and
  dropping a flare change nothing in the weapon table or anywhere else that
  behaves like a count. So there is no "infinite ammo" cheat.
- The sound chip's reverb is never switched on (`spu_status` in the intro
  movie and in mission 1: `reverb_on=0`, `eon=0`), so there is no reverb mute.
- Mission 1: "shoot down the unmanned drone" (training, nothing fires back).
  Mission 2: smaller, faster drones that fire missiles.
- Aborting a mission (pause, Abort Mission, Yes) costs a life and returns
  to the debrief with Mission Failed; Continue replays the same mission.
  Waiting for enemies to shoot the jet down is unreliable (they rarely do
  within four minutes of hands-off flight), so tests use the abort.
- The disc's movie folders name the theatres: Miramar (training), Libya,
  Korea, Cuba.
- Memory card saves work: `tests/route_memcard_save.txt` (debrief, Save Game,
  Memory Card, initials) shows "GAME SAVED", and the card file then holds
  the entry `BASLUS-00032AAA01`.
- The debrief menu offers Continue / Abort Game / Save Game / Options; the
  title's Restore Game offers Memory Card or Password.

## Cheats not made

- **Can't be hit**: the damage values were not found (below). Infinite lives
  covers being shot down.

## Dead ends (kept so nobody repeats them)

- Damage: the HUD silhouette shows damage per part (wings turn orange/red).
  Snapshot diffs across a caught hit (`tests/catch_event.py`) changed
  thousands of bytes (scenery streaming in at the same moment), and the
  values that changed identically at two separate hits were stack and
  pointer data. Poked without effect: `0x8019F9D0`, `0x801CCF64`,
  `0x8019F9C8`, `0x801CCF5C`, `0x801CFF14` (0x40 and 0). A write trace over
  0x80180000-0x801F0000 around a caught hit (`TGFAW_WTRACE` in
  `tests/catch_event.py`) showed three values dropping together at
  0x80191BC8/BD8/BDA, but that object is an explosion effect, not the jet.
  Kill counters (`0x8019FE2C`/`32`) set to the goal do not end a mission.
  Next approach: find the code that colours the HUD silhouette, not the data.
- Routes replay input exactly (`input_route_start at_frame=30`), but enemy
  drones drift between runs after ~20 s of flight, and the mission's opening
  fly-by ends at slightly different times. Cheat checks therefore wait well
  past the fly-by and compare outcomes, not exact frames.
