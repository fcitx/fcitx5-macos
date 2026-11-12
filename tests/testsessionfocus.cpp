#include <string>
#include <vector>
#include <fcitx-utils/log.h>
#include <fcitx-utils/testing.h>
#include <fcitx/userinterfacemanager.h>
#include "../macosfrontend/macosfrontend.h"

using namespace fcitx;

int main() {
    setupTestingEnvironmentPath(".", {}, {});
    char name[] = "testsessionfocus";
    char disable[] = "--disable=all";
    char *argv[] = {name, disable};
    Instance instance(2, argv);
    instance.initialize();
    MacosFrontend frontend(&instance);
    auto uuidA = frontend.createInputContext("A", "");
    auto uuidB = frontend.createInputContext("B", "");
    auto &manager = instance.inputContextManager();
    auto *a = static_cast<MacosInputContext *>(manager.findByUUID(uuidA));
    auto *b = static_cast<MacosInputContext *>(manager.findByUUID(uuidB));
    InputSessionIdentity firstA{uuidA, 1, 1, 1};
    InputSessionIdentity secondA{uuidA, 1, 1, 2};
    InputSessionIdentity thirdA{uuidA, 1, 1, 3};
    InputSessionIdentity firstB{uuidB, 1, 2, 1};
    auto expectedA = firstA;
    std::vector<std::string> events;
    auto checkIdentity = [&](Event &event) {
        auto *ic = static_cast<MacosInputContext *>(
            static_cast<InputContextEvent &>(event).inputContext());
        FCITX_ASSERT(ic->matchesSession(ic == a ? expectedA : firstB));
        return ic;
    };
    auto focusIn = instance.watchEvent(
        EventType::InputContextFocusIn, EventWatcherPhase::PreInputMethod,
        [&](Event &event) {
            auto *ic = checkIdentity(event);
            events.push_back("in:" + ic->program());
        });
    auto focusOut = instance.watchEvent(
        EventType::InputContextFocusOut, EventWatcherPhase::PreInputMethod,
        [&](Event &event) {
            auto *ic = checkIdentity(event);
            events.push_back("out:" + ic->program());
            // Model a final update deferred by a focus-out handler.
            instance.userInterfaceManager().update(
                UserInterfaceComponent::InputPanel, ic);
        });
    auto flush = instance.watchEvent(
        EventType::InputContextFlushUI, EventWatcherPhase::PreInputMethod,
        [&](Event &event) {
            auto *ic = checkIdentity(event);
            events.push_back("flush:" + ic->program());
            ic->commitStringImpl("tail");
        });

    // Exercise core focus and binding without refreshing candidate-window or
    // app policy. A stable identity must still update password capabilities
    // when Terminal enters and leaves sudo password input.
    frontend.focusIn(firstA, false, false);
    FCITX_ASSERT(a->hasFocus());
    FCITX_ASSERT(!a->capabilityFlags().test(CapabilityFlag::Password));
    frontend.focusIn(firstA, true, false);
    FCITX_ASSERT(a->capabilityFlags().test(CapabilityFlag::Password));
    frontend.focusIn(firstA, false, false);
    FCITX_ASSERT(!a->capabilityFlags().test(CapabilityFlag::Password));
    FCITX_ASSERT(events == std::vector<std::string>{"in:A"});

    frontend.focusOut(firstA);
    FCITX_ASSERT(!a->hasFocus() && !a->matchesSession(firstA));
    FCITX_ASSERT(events.back() == "flush:A");
    auto afterClose = events.size();
    frontend.focusOut(firstA);
    FCITX_ASSERT(events.size() == afterClose);

    expectedA = secondA;
    frontend.focusIn(secondA, false, false);
    frontend.focusOut(firstA);
    FCITX_ASSERT(a->hasFocus() && a->matchesSession(secondA));

    // B's focus-in already focuses A out. Closing A must flush its tail
    // without focusing B out or emitting a second focus-out event for A.
    frontend.focusIn(firstB, false, false);
    FCITX_ASSERT(!a->hasFocus() && b->hasFocus());
    frontend.focusOut(secondA);
    FCITX_ASSERT(!a->matchesSession(secondA));
    FCITX_ASSERT(b->hasFocus() && b->matchesSession(firstB));

    expectedA = thirdA;
    frontend.focusIn(thirdA, false, false);
    frontend.focusOut(secondA);
    FCITX_ASSERT(a->hasFocus() && a->matchesSession(thirdA));
    frontend.focusOut(firstB);
    FCITX_ASSERT(a->hasFocus() && !b->matchesSession(firstB));
    frontend.focusOut(thirdA);
    FCITX_ASSERT(!a->hasFocus() && !a->matchesSession(thirdA));
    FCITX_ASSERT(events == (std::vector<std::string>{
                               "in:A", "out:A", "flush:A", "in:A", "out:A",
                               "in:B", "flush:A", "out:B", "in:A", "flush:B",
                               "out:A", "flush:A"}));
    frontend.destroyInputContext(uuidA);
    frontend.destroyInputContext(uuidB);
}
