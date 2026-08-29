#include "quickphrase-public.h"

#include <string>
#include <string_view>
#include <utility>

#include <fcitx-utils/macros.h>
#include <fcitx-utils/stringutils.h>
#include <nlohmann/json.hpp>

std::string quickphrase_parse_line(const char *line) noexcept {
    try {
        std::string_view text = fcitx::stringutils::trimView(line);
        if (text.empty()) {
            return "null";
        }

        auto pos = text.find_first_of(FCITX_WHITESPACE);
        if (pos == std::string_view::npos) {
            return "null";
        }

        auto word = text.find_first_not_of(FCITX_WHITESPACE, pos);
        if (word == std::string_view::npos) {
            return "null";
        }

        auto phrase = fcitx::stringutils::unescapeForValue(text.substr(word));
        if (!phrase) {
            return "null";
        }

        return nlohmann::json({{"keyword", std::string(text.substr(0, pos))},
                               {"phrase", std::move(*phrase)}})
            .dump();
    } catch (...) {
        return "null";
    }
}

std::string quickphrase_serialize_line(const char *keyword,
                                       const char *phrase) noexcept {
    try {
        return std::string(keyword) + " " +
               fcitx::stringutils::escapeForValue(phrase);
    } catch (...) {
        return {};
    }
}
