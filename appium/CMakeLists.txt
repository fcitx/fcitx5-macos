add_executable(FcitxTestApp
    MACOSX_BUNDLE
    entry.swift
    TestConfigView.swift
)

target_link_libraries(FcitxTestApp
    FcitxConfigUI
)

set_target_properties(FcitxTestApp PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
)
