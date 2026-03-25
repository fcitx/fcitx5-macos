#pragma once
#include <string>

std::string customphrase_get(const char *path) noexcept;
bool customphrase_set(const char *path, const char *json) noexcept;
