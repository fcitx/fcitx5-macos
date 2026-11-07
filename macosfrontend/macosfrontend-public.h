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

void bind_input_session(InputSessionIdentity identity) noexcept;
void close_input_session(InputSessionIdentity identity) noexcept;

// The JSON and its FIFO position are captured in the same core-thread call.
struct OrderedInputResponse {
    std::string response;
    uint64_t outputBoundary = 0;
};

OrderedInputResponse process_key_ordered(ICUUID uuid, uint32_t unicode,
                                         uint32_t osxModifiers,
                                         uint16_t osxKeycode, bool isRelease,
                                         bool isPassword, const char *text,
                                         unsigned int cursor,
                                         unsigned int anchor) noexcept;
OrderedInputResponse commit_composition_ordered(ICUUID uuid) noexcept;

// Though being UInt, 32b is enough for modifiers
std::string process_key(ICUUID uuid, uint32_t unicode, uint32_t osxModifiers,
                        uint16_t osxKeycode, bool isRelease, bool isPassword,
                        const char *text, unsigned int cursor,
                        unsigned int anchor) noexcept;

ICUUID create_input_context(const char *appId,
                            const char *accentColor) noexcept;
void destroy_input_context(ICUUID uuid) noexcept;
void focus_in(ICUUID uuid, bool isPassword) noexcept;
std::string commit_composition(ICUUID uuid) noexcept;
void focus_out(ICUUID uuid) noexcept;
std::string get_current_group_layout() noexcept;
