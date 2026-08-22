#include "fcitx-utils/keysym.h"
#include "fcitx-utils/log.h"
#include "keycode.h"

#define kVK_DUMMY 0xff

void test_osx_to_fcitx() {
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, kVK_DUMMY) == FcitxKey_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('0', 0, kVK_ANSI_Keypad0) ==
                 FcitxKey_KP_0);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym('a', 0, kVK_DUMMY) == FcitxKey_a);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(0, 0, kVK_DUMMY) == FcitxKey_None);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(
                     0, 0, kVK_ANSI_A /* 0, common error */) == FcitxKey_None);

    ::pinyinKeyboard = true;
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(65292 /* ， */, 0,
                                             kVK_ANSI_Comma) == FcitxKey_comma);
    FCITX_ASSERT(
        osx_unicode_to_fcitx_keysym(12299 /* 》 */, NSEventModifierFlagShift,
                                    kVK_ANSI_Period) == FcitxKey_greater);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(
                     12299 /* 》 */,
                     NSEventModifierFlagShift | NSEventModifierFlagControl,
                     kVK_ANSI_Period) == FcitxKey_period);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(0, 0, kVK_DUMMY) == FcitxKey_None);
    FCITX_ASSERT(osx_unicode_to_fcitx_keysym(
                     0, 0, kVK_ANSI_A /* 0, common error */) == FcitxKey_None);
    ::pinyinKeyboard = false;

    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_ANSI_0) == 11 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_ANSI_Keypad0) == 82 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_Shift) == 42 + 8);
    FCITX_ASSERT(osx_keycode_to_fcitx_keycode(kVK_RightShift) == 54 + 8);

    FCITX_ASSERT(
        osx_modifiers_to_fcitx_keystates(NSEventModifierFlagControl |
                                         NSEventModifierFlagShift) ==
        (fcitx::KeyStates{} | fcitx::KeyState::Ctrl | fcitx::KeyState::Shift));
}

void test_fcitx_to_osx() {
    FCITX_ASSERT(fcitx_keysym_to_osx_function_key(FcitxKey_Up) == 0xF700);
    FCITX_ASSERT(fcitx_keysym_to_osx_function_key(FcitxKey_F12) == 0xF70F);

    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_Left) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_F12) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_0) == "0");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_KP_0) == "");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_grave) == "`");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_a) == "a");
    FCITX_ASSERT(fcitx_keysym_to_osx_keysym(FcitxKey_A) == "a");

    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_KP_0) ==
                 kVK_ANSI_Keypad0);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_L) == kVK_Shift);
    FCITX_ASSERT(fcitx_keysym_to_osx_keycode(FcitxKey_Shift_R) ==
                 kVK_RightShift);

    FCITX_ASSERT(fcitx_keystates_to_osx_modifiers(fcitx::KeyStates{} |
                                                  fcitx::KeyState::Super |
                                                  fcitx::KeyState::Alt) ==
                 (NSEventModifierFlagCommand | NSEventModifierFlagOption));
}

void test_fcitx_string() {
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Left") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("F12") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+0") == "0");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+Shift+KP_0") == "");
    FCITX_ASSERT(fcitx_string_to_osx_keysym("Control+slash") == "/");

    FCITX_ASSERT(fcitx_string_to_osx_modifiers("Control+Super+K") ==
                 (NSEventModifierFlagControl | NSEventModifierFlagCommand));

    FCITX_ASSERT(fcitx_string_to_osx_keycode("Alt+Shift+Shift_L") == kVK_Shift);
    FCITX_ASSERT(fcitx_string_to_osx_keycode("Shift_R") == kVK_RightShift);
}

void test_keycode_to_unicode() {
    // Layout-independent special keys have no unicode.
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_F1, 0) == 0);
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_Shift, 0) == 0);
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_Return, 0) == 0);
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_Keypad0, 0) == 0);

    // Alphabet: lowercase without shift, uppercase with shift, caps handled.
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_A, 0) == 'a');
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_A,
                                            NSEventModifierFlagShift) == 'A');
    FCITX_ASSERT(osx_keycode_to_osx_unicode(
                     kVK_ANSI_A, NSEventModifierFlagCapsLock) == 'A');
    FCITX_ASSERT(osx_keycode_to_osx_unicode(
                     kVK_ANSI_A, NSEventModifierFlagCapsLock |
                                     NSEventModifierFlagShift) == 'a');

    // Symbols: Shift+comma -> less, Control+Shift+comma -> comma.
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_Comma, 0) == ',');
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_Comma,
                                            NSEventModifierFlagShift) == '<');
    FCITX_ASSERT(osx_keycode_to_osx_unicode(
                     kVK_ANSI_Comma, NSEventModifierFlagShift |
                                         NSEventModifierFlagControl) == ',');

    // Dvorak maps the Q key to apostrophe.
    currentLayout = "us-dvorak";
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_Q, 0) == '\'');

    // PinyinKeyboard falls back to us.
    currentLayout = "PinyinKeyboard";
    pinyinKeyboard = true;
    FCITX_ASSERT(osx_keycode_to_osx_unicode(kVK_ANSI_Comma,
                                            NSEventModifierFlagShift) == '<');
}

void test_unicode_to_fcitx_string() {
    FCITX_ASSERT(osx_key_to_fcitx_string('a', NSEventModifierFlagControl, 0) ==
                 "Control+A");
    FCITX_ASSERT(osx_key_to_fcitx_string(
                     'A', NSEventModifierFlagControl | NSEventModifierFlagShift,
                     0) == "Control+Shift+A");
    FCITX_ASSERT(osx_key_to_fcitx_string(
                     ',', NSEventModifierFlagControl | NSEventModifierFlagShift,
                     kVK_ANSI_Comma) == "Control+comma");
    FCITX_ASSERT(osx_key_to_fcitx_string('<', NSEventModifierFlagShift,
                                         kVK_ANSI_Comma) == "less");
    FCITX_ASSERT(osx_key_to_fcitx_string(
                     0, NSEventModifierFlagOption | NSEventModifierFlagShift,
                     kVK_Shift) == "Alt+Shift+Shift_L");
}

int main() {
    setenv(
        "XKB_CONFIG_ROOT",
        "/Library/Input Methods/Fcitx5.app/Contents/share/xkeyboard-config-2",
        1);
    test_osx_to_fcitx();
    test_fcitx_to_osx();
    test_fcitx_string();
    test_keycode_to_unicode();
    test_unicode_to_fcitx_string();
}
