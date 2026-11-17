pragma Singleton

import QtQuick
import Quickshell

// The tooltips of the shell behave as a group, as Material asks: the first one waits for its delay, but moving along
// a row of controls the next one shows at once, while one is showing or was a moment ago.
Singleton {
    id: root

    property bool warm
    property int showing

    function opened(): void {
        root.showing++;
        root.warm = true;
        cool.stop();
    }

    function closed(): void {
        root.showing = Math.max(0, root.showing - 1);
        if (root.showing === 0)
            cool.restart();
    }

    Timer {
        id: cool

        interval: 400
        onTriggered: root.warm = false
    }
}
