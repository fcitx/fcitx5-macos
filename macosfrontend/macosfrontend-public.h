#pragma once

#include <array>
#include <cstdint>
#include <string>

// Identical to fcitx::ICUUID. Replicated for Swift interop.
typedef std::array<uint8_t, 16> ICUUID;

struct InputSessionIdentity {
    ICUUID uuid{};
    uint64_t runtimeEpoch = 0;
    uint64_t registrationGeneration = 0;
    uint64_t activationGeneration = 0;

    bool operator==(const InputSessionIdentity &other) const {
        return uuid == other.uuid && runtimeEpoch == other.runtimeEpoch &&
               registrationGeneration == other.registrationGeneration &&
               activationGeneration == other.activationGeneration;
    }
};

void focus_in(InputSessionIdentity identity, bool isPassword,
              bool refreshAppPolicy) noexcept;
void focus_out(InputSessionIdentity identity) noexcept;

// The input result and its FIFO position are captured in the same core-thread
// call.
struct InputResponse {
    std::string commit;
    std::string preedit;
    int caretPos = 0;
    bool dummyPreedit = false;
    bool accepted = false;
    // An invalid context has no presentation to apply, but still has a
    // boundary.
    bool valid = false;
    uint64_t outputBoundary = 0;
};

InputResponse process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                          uint16_t osxKeycode, bool isRelease, const char *text,
                          unsigned int cursor, unsigned int anchor) noexcept;
InputResponse commit_composition(ICUUID uuid) noexcept;

ICUUID create_input_context(const char *appId,
                            const char *accentColor) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
std::string get_current_group_layout() noexcept;
