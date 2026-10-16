cmake_minimum_required(VERSION 3.20)
set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/vendor/psxrecomp" CACHE PATH
    "Path to psxrecomp")
if(NOT EXISTS "${PSXRECOMP_ROOT}/runtime/runtime.cmake")
    message(FATAL_ERROR
        "PSXRecomp runtime is missing: ${PSXRECOMP_ROOT}/runtime/runtime.cmake\n"
        "This project expects the psxrecomp framework checkout at ${PSXRECOMP_ROOT}.\n"
        "Run: ./setup.sh\n"
        "If psxrecomp/ is not a submodule, set -DPSXRECOMP_ROOT=<path-to-psxrecomp>.")
endif()

project(TopGunFireAtWillRecomp LANGUAGES C CXX)

# Engines live in vendor/ (fetched and patched by setup.sh), not submodules.
set(RECOMP_UI_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/vendor/recomp-ui" CACHE PATH "recomp-ui checkout")

# --- Opt-in product surfaces (OFF by default in the framework) -------------
# Scaffold prompts / flags fill these. Without recomp-ui, PSX_RECOMP_UI is OFF.
# The wizard (WIZARD_CMAKE_BLOCK / ENABLE_SETUP_WIZARD) is the first-run disc
# picker; releases are compiled from the committed generated/ C, so it never
# needs to generate or rebuild anything on a player's machine.
# recomp-ui submodule present (PSX_RECOMP_UI defaults ON).
# Full netplay UI — enable after adding recomp-ui + testing:
# if(EXISTS "${PSXRECOMP_ROOT}/lib/recomp-net/CMakeLists.txt")
#     set(PSX_NETPLAY ON CACHE BOOL "…" FORCE)
# endif()
# First-run setup wizard — enable after testing:
# set(PSX_SETUP_WIZARD ON CACHE BOOL "…" FORCE)
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# This project's own mod catalog. The FRAMEWORK stages it -- together with its
# builtin psx.* packages -- into <exe-dir>/mods/bundled, and refuses to
# configure if a catalog exists here but is not declared. Never copy it by
# hand: five titles did, and framework 4cc04be3's rename of the staged
# directory broke all five silently (bead beads-eio.3.101).
set(PSX_PRELOADED_MODS "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")
if(NOT IS_DIRECTORY "${PSX_PRELOADED_MODS}")
    set(PSX_PRELOADED_MODS "NONE")
endif()

psxrecomp_add_game_runtime(psx-runtime
    PRELOADED_MODS_DIR "${PSX_PRELOADED_MODS}"
    # ENABLE_NETPLAY_IF_PRESENT
    # NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
    # ENABLE_SETUP_WIZARD
    WINDOW_TITLE "Top Gun: Fire at Will"
    # The Mac settings folder follows the program name.
    EXE_NAME "TopGunFireAtWill"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 1
    # LAUNCHER_BOXART "${CMAKE_CURRENT_SOURCE_DIR}/launcher_assets/img/boxart.tga"
    APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon/topgunfaw.ico"
    # Committed game C (psxrecomp_cli.py generate; git add generated). Release
    # CI configures with -DPSXRECOMP_REQUIRE_GAME_C=ON so a checkout without
    # it fails instead of building a setup host.
    GEN_MARKER "generated/SLUS_000.32_dispatch.c"
    GEN_FULL_GLOB "generated/SLUS_000.32_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
)

# Stage runtime configs next to the exe for direct build/ launches. Only copy
# files that exist — never fail POST_BUILD when game_options.toml is absent.
foreach(_PSX_RUNTIME_CONFIG game.toml game_options.toml)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}")
        add_custom_command(TARGET psx-runtime POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}"
                "$<TARGET_FILE_DIR:psx-runtime>/${_PSX_RUNTIME_CONFIG}"
            COMMENT "Staging ${_PSX_RUNTIME_CONFIG}"
            VERBATIM)
    endif()
endforeach()

# The port's own code: Game page rows, About page, cheats, audio switches.
target_sources(psx-runtime PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/topgunfaw_ui.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/topgunfaw_extras.c)
target_include_directories(psx-runtime PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# About page signature and the controller database (pads work with no setup).
add_custom_command(TARGET psx-runtime POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:psx-runtime>/assets/img"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/signature.png"
        "$<TARGET_FILE_DIR:psx-runtime>/assets/img/maddie-signature.png"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/controllers/gamecontrollerdb.txt"
        "$<TARGET_FILE_DIR:psx-runtime>/assets/gamecontrollerdb.txt"
    # Launcher header mark: the port's own icon, over the PS1 profile's mark.
    COMMAND ${CMAKE_COMMAND} -E copy
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon/topgunfaw-brand.tga"
        "$<TARGET_FILE_DIR:psx-runtime>/assets/img/brand_psx.tga"
    VERBATIM)
