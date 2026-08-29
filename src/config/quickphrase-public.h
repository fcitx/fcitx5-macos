#pragma once
#include <string>

// Returns a JSON-encoded {"keyword": ..., "phrase": ...}, or null if the
// line is invalid.
std::string quickphrase_parse_line(const char *line) noexcept;

std::string quickphrase_serialize_line(const char *keyword,
                                       const char *phrase) noexcept;
