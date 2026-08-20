add_library(Keycode STATIC keycode.cpp)
target_include_directories(Keycode PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_BINARY_DIR}/fcitx5"
)
target_link_libraries(Keycode Fcitx5::Utils XKBCommon::XKBCommon)
