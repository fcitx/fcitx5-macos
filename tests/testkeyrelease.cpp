#include <cstddef>
#include <memory>
#include <fcitx-utils/log.h>
#include <fcitx-utils/testing.h>
#include <nlohmann/json.hpp>
#include "../macosfrontend/macosfrontend.h"

using namespace fcitx;

enum class BeforeRelease { None, FocusOut, SwitchFocus, Destroy, ReuseAddress };

void test_key_release(BeforeRelease beforeRelease) {
    char name[] = "testkeyrelease";
    char disable[] = "--disable=all";
    char *argv[] = {name, disable};
    Instance instance(2, argv);
    instance.initialize();
    MacosFrontend frontend(&instance);
    RawConfig config;
    config.setValueByPath("SimulateKeyRelease", "True");
    config.setValueByPath("SimulateKeyReleaseDelay", "10");
    config.setValueByPath("MonitorPasteboard", "False");
    // Change the in-memory configuration without saving user settings.
    const_cast<Configuration *>(frontend.getConfig())->load(config, true);
    frontend.updateConfig();

    int releases = 0;
    ICUUID releaseUuid{};
    auto handler = instance.watchEvent(
        EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
        [&](Event &event) {
            auto &keyEvent = static_cast<KeyEvent &>(event);
            if (keyEvent.isRelease()) {
                ++releases;
                releaseUuid = keyEvent.inputContext()->uuid();
            }
            // Accept the key without requiring an input method
            // addon.
            keyEvent.filterAndAccept();
        });

    auto &manager = instance.inputContextManager();
    FocusGroup group("test", manager);
    // Placement construction makes address reuse deterministic.
    alignas(MacosInputContext) std::byte storage[sizeof(MacosInputContext)];
    auto makeContext = [&]() {
        auto *ic =
            std::construct_at(reinterpret_cast<MacosInputContext *>(storage),
                              &frontend, manager, "test", "");
        ic->setFocusGroup(&group);
        return ic;
    };
    auto *ic = makeContext();
    const auto uuid = ic->uuid();
    const auto response = nlohmann::json::parse(
        frontend.keyEvent(uuid, Key(FcitxKey_a), false, false, "", 0, 0));
    FCITX_ASSERT(response["accepted"].get<bool>());

    std::unique_ptr<MacosInputContext> other;
    switch (beforeRelease) {
    case BeforeRelease::None:
        break;
    case BeforeRelease::FocusOut:
        ic->focusOut();
        break;
    case BeforeRelease::SwitchFocus:
        other = std::make_unique<MacosInputContext>(&frontend, manager, "other",
                                                    "");
        other->setFocusGroup(&group);
        other->focusIn();
        FCITX_ASSERT(!ic->hasFocus());
        break;
    case BeforeRelease::Destroy:
        std::destroy_at(ic);
        ic = nullptr;
        break;
    case BeforeRelease::ReuseAddress:
        std::destroy_at(ic);
        ic = makeContext();
        FCITX_ASSERT(ic->uuid() != uuid);
        ic->focusIn();
        FCITX_ASSERT(instance.mostRecentInputContext() == ic);
        break;
    }

    // Let the actual frontend timer run before stopping the event loop.
    auto stop = instance.eventLoop().addTimeEvent(
        CLOCK_MONOTONIC, now(CLOCK_MONOTONIC) + 100000, 0,
        [&](EventSourceTime *, uint64_t) {
            instance.eventLoop().exit();
            return true;
        });
    instance.eventLoop().exec();

    if (beforeRelease == BeforeRelease::None) {
        FCITX_ASSERT(releases == 1);
        FCITX_ASSERT(releaseUuid == uuid);
    } else {
        FCITX_ASSERT(releases == 0);
    }
    if (ic) {
        std::destroy_at(ic);
    }
}

int main() {
    setupTestingEnvironmentPath(".", {}, {});
    for (auto beforeRelease :
         {BeforeRelease::None, BeforeRelease::FocusOut,
          BeforeRelease::SwitchFocus, BeforeRelease::Destroy,
          BeforeRelease::ReuseAddress}) {
        test_key_release(beforeRelease);
    }
}
