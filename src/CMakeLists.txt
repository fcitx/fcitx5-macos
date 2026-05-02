execute_process(COMMAND git rev-parse HEAD
    OUTPUT_VARIABLE COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(COMMAND git show --no-patch --format=%ct
    OUTPUT_VARIABLE UNIX_TIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
configure_file(config/meta.swift.in ${CMAKE_CURRENT_SOURCE_DIR}/config/meta.swift @ONLY)

file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_library(Fcitx5Objs STATIC
    fcitx.cpp
    layout.cpp
    remote.cpp
    tunnel.cpp
    config/config.cpp
    config/customphrase.cpp
)

target_include_directories(Fcitx5Objs PRIVATE
    "${PROJECT_BINARY_DIR}/fcitx5"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/im/keyboard"
)

# This should be disabled in CI even for debug build.
option(KEY_LOGGING "Enable key logging" ON)
if(KEY_LOGGING)
    target_compile_definitions(Fcitx5Objs PRIVATE KEY_LOGGING)
endif()

target_link_libraries(Fcitx5Objs
    Fcitx5::Core
    keyboard
    webpanel
    beast
    macosfrontend
    notifications
    WebviewCandidateWindow
)

# Config UI library - compiled once, linked by both Fcitx5 and Fcitx5TestApp
add_library(FcitxConfigUI STATIC
    ${CONFIG_UI_FILES}
)

target_link_libraries(FcitxConfigUI PUBLIC
    Fcitx5Objs
    Logging
    AlertToast
    SwiftFrontend
)

add_executable(Fcitx5
    MACOSX_BUNDLE
    server.swift
    locale.swift
    controller.swift
    menu.swift
    secure.swift
    status.swift
)

target_link_libraries(Fcitx5
    FcitxConfigUI
    SwiftNotify
)

fcitx5_import_addons(Fcitx5
    REGISTRY_VARNAME getStaticAddon
    ADDONS beast keyboard webpanel macosfrontend notifications
)

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents")

set(BINARY_LIB_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/lib")
set(BINARY_MODULE_PATH "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

add_custom_command(TARGET Fcitx5 POST_BUILD
    COMMAND rm -f "${CMAKE_CURRENT_BINARY_DIR}/Fcitx5.app/Contents/MacOS/Fcitx5.d"
)

install(TARGETS Fcitx5
    BUNDLE DESTINATION "${APP_INSTALL_PATH}"
)
