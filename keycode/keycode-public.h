#pragma once

#include <cstdint>
#include <string>
#include <utility>

struct xkb_context;
struct xkb_keymap;

uint32_t osx_keycode_to_osx_unicode(uint16_t osxKeycode,
                                    uint32_t osxModifiers) noexcept;
std::pair<struct xkb_context *, struct xkb_keymap *>
make_xkb_keymap(const std::string &layout) noexcept;
std::string osx_key_to_fcitx_string(uint32_t unicode, uint32_t modifiers,
                                    uint16_t code) noexcept;
std::string fcitx_string_to_osx_keysym(const char *) noexcept;
uint32_t fcitx_string_to_osx_modifiers(const char *) noexcept;
uint16_t fcitx_string_to_osx_keycode(const char *) noexcept;
std::string fcitx_string_to_localized_string(const char *) noexcept;
