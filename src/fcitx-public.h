#pragma once

#include <string>

void start_fcitx_thread(const char *locale) noexcept;
void stop_fcitx_thread() noexcept;
void reload();
void setupI18N();

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
// Returns a json array of group names.
std::string imGetGroupNames() noexcept;
std::string imGetCurrentGroupName() noexcept;
void imSetCurrentGroup(const char *groupName) noexcept;

// Returns a json array of { "name": ..., "displayName": ... }
std::string imGetCurrentGroup() noexcept;

int imGroupCount() noexcept;
void imAddToCurrentGroup(const char *imName) noexcept;

// Returns json
// [{"name": "group name", "inputMethods":
//   [{"name": ..., "displayName": ...}...]}...].
std::string imGetGroups() noexcept;
void imSetGroups(const char *json) noexcept;

std::string imGetCurrentIMName() noexcept;
// Returns a json object mapping input method names to their imselector
// SwitchKey.
std::string imGetSwitchKeys() noexcept;
void imSetCurrentIM(const char *imName, bool hotkey = false) noexcept;
void setInputMethodLayout(const char *group, const char *im,
                          const char *layout) noexcept;
void toggleInputMethod() noexcept;

// Returns a json array of Input Methods.
// type InputMethod := {name:str, displayName:str, languageCode:str}
std::string imGetAvailableIMs() noexcept;

std::string getAddons() noexcept;

std::string getActions() noexcept;
void activateActionById(int id, bool hotkey) noexcept;

std::string isoName(const char *code) noexcept;

// Check whether the string is a valid regular expression, using the same
// rules as fcitx's regex option constrain.
bool isRegexValid(const char *regex) noexcept;

std::string getSymbolsOfLayout(const char *layout, bool shift) noexcept;

// Tunnel variables
#include "tunnel.h"
