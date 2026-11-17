#pragma once

#include <optional>

namespace sylenara::shell::services::sensorslib {

void ensureInit();

[[nodiscard]] std::optional<double> cpuPackageTemp();
[[nodiscard]] std::optional<double> gpuPciAverageTemp();

} // namespace sylenara::shell::services::sensorslib
