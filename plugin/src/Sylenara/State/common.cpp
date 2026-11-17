#include "common.hpp"

#include <qstandardpaths.h>

namespace sylenara::shell::state {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcState, "sylenara.state", QtInfoMsg)

QString stateDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + u"/sylenara"_s;
}

QString monitorStateDir() {
    return stateDir() + u"/monitors"_s;
}

QString runtimeDir() {
    return QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + u"/sylenara"_s;
}

QString monitorRuntimeDir() {
    return runtimeDir() + u"/monitors"_s;
}

} // namespace sylenara::shell::state
