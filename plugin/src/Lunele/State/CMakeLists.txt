qml_module(lunele-state
    URI Lunele.State
    INCLUDE_PREFIX state
    SOURCES
        common.cpp
        rootnodes.cpp
    DEPENDENCIES
        Lunele.Settings
)
target_link_libraries(lunele-state PUBLIC lunele-settings)
