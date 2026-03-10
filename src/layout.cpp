#include <nlohmann/json.hpp>
#include <xkbcommon/xkbcommon.h>
#include "fcitx-public.h"
#include "../fcitx5/src/lib/fcitx-utils/key.h"
#include "../fcitx5/src/lib/fcitx/misc_p.h"

std::string getSymbolsOfLayout(const char *layout, bool shift) noexcept {
    auto [layoutStr, variant] = fcitx::parseLayout(layout);

    struct xkb_context *ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx) {
        return "[]";
    }

    struct xkb_rule_names names = {.rules = "evdev",
                                   .model = "pc105",
                                   .layout = layoutStr.c_str(),
                                   .variant = variant.empty() ? nullptr
                                                              : variant.c_str(),
                                   .options = nullptr};

    struct xkb_keymap *keymap =
        xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!keymap) {
        xkb_context_unref(ctx);
        return "[]";
    }

    static constexpr const char *row1Keys[] = {
        "TLDE", "AE01", "AE02", "AE03", "AE04", "AE05", "AE06",
        "AE07", "AE08", "AE09", "AE10", "AE11", "AE12"};
    static constexpr const char *row2Keys[] = {
        "AD01", "AD02", "AD03", "AD04", "AD05", "AD06", "AD07",
        "AD08", "AD09", "AD10", "AD11", "AD12", "BKSL"};
    static constexpr const char *row3Keys[] = {"AC01", "AC02", "AC03", "AC04",
                                               "AC05", "AC06", "AC07", "AC08",
                                               "AC09", "AC10", "AC11"};
    static constexpr const char *row4Keys[] = {"AB01", "AB02", "AB03", "AB04",
                                               "AB05", "AB06", "AB07", "AB08",
                                               "AB09", "AB10"};

    auto getRow = [&](auto &keys, bool s) {
        nlohmann::json row = nlohmann::json::array();
        for (const auto &keyName : keys) {
            xkb_keycode_t key = xkb_keymap_key_by_name(keymap, keyName);
            std::string utf8;
            if (key != XKB_KEYCODE_INVALID) {
                const xkb_keysym_t *syms = nullptr;
                xkb_keymap_key_get_syms_by_level(keymap, key, 0, s ? 1 : 0,
                                                 &syms);
                if (syms && syms[0]) {
                    utf8 = fcitx::Key::keySymToUTF8(
                        static_cast<fcitx::KeySym>(syms[0]));
                }
            }
            row.push_back(utf8);
        }
        return row;
    };

    nlohmann::json result = nlohmann::json::array();
    result.push_back(getRow(row1Keys, shift));
    result.push_back(getRow(row2Keys, shift));
    result.push_back(getRow(row3Keys, shift));
    result.push_back(getRow(row4Keys, shift));

    xkb_keymap_unref(keymap);
    xkb_context_unref(ctx);

    return result.dump();
}
