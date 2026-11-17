qml_module(sylenara-state
    URI Sylenara.State
    INCLUDE_PREFIX state
    SOURCES
        common.cpp
        rootnodes.cpp
    DEPENDENCIES
        Sylenara.Settings
)
target_link_libraries(sylenara-state PUBLIC sylenara-settings)
