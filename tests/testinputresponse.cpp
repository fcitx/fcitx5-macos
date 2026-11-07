#include <fcitx-utils/log.h>
#include <fcitx-utils/testing.h>
#include <fcitx/inputpanel.h>
#include <nlohmann/json.hpp>
#include "../macosfrontend/macosfrontend.h"

using namespace fcitx;

int main() {
    setupTestingEnvironmentPath(".", {}, {});
    char name[] = "testinputresponse";
    char disable[] = "--disable=all";
    char *argv[] = {name, disable};
    Instance instance(2, argv);
    instance.initialize();
    MacosFrontend frontend(&instance);
    auto uuid = frontend.createInputContext("test", "");
    auto *ic = static_cast<MacosInputContext *>(
        instance.inputContextManager().findByUUID(uuid));
    auto handler = instance.watchEvent(
        EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
        [&](Event &event) {
            ic->commitStringImpl("a");
            Text preedit("ni");
            preedit.setCursor(2);
            ic->inputPanel().setClientPreedit(preedit);
            ic->updatePreeditImpl();
            static_cast<KeyEvent &>(event).filterAndAccept();
        });

    auto legacy =
        frontend.keyEvent(uuid, Key(FcitxKey_a), false, false, "", 0, 0);
    auto ordered =
        frontend.keyEventOrdered(uuid, Key(FcitxKey_a), false, false, "", 0, 0);
    FCITX_ASSERT(ordered.response == legacy);
    FCITX_ASSERT(ordered.outputBoundary > 0);
    const auto json = nlohmann::json::parse(ordered.response);
    FCITX_ASSERT(json["commit"] == "a");
    FCITX_ASSERT(json["preedit"] == "ni");
    FCITX_ASSERT(json["caretPos"] == 2);
    FCITX_ASSERT(json["accepted"] == true);
    FCITX_ASSERT(json.size() == 5);

    auto legacyComposition = frontend.commitComposition(uuid);
    auto orderedComposition = frontend.commitCompositionOrdered(uuid);
    FCITX_ASSERT(orderedComposition.response == legacyComposition);
    FCITX_ASSERT(orderedComposition.outputBoundary > ordered.outputBoundary);

    frontend.destroyInputContext(uuid);
    auto missing =
        frontend.keyEventOrdered(uuid, Key(FcitxKey_a), false, false, "", 0, 0);
    FCITX_ASSERT(missing.response == "{}");
    FCITX_ASSERT(missing.outputBoundary > orderedComposition.outputBoundary);
    return 0;
}
