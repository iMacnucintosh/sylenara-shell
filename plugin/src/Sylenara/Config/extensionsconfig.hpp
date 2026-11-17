#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace sylenara::shell::config {

class ExtensionsConfig : public settings::ObjectNode {
    CONFIG_NODE(ExtensionsConfig, settings::ObjectNode)

    // Ids of the enabled extensions (see services/Extensions.qml). Nothing is enabled by default.
    CONFIG_PROPERTY(QStringList, enabled, {})
};

} // namespace sylenara::shell::config
