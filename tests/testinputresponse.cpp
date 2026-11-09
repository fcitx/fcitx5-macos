#include <fcitx-utils/log.h>
#include <fcitx-utils/testing.h>
#include <fcitx/inputpanel.h>
#include "../keycode/keycode.h"
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
        fcitx::EventType::InputContextKeyEvent,
        EventWatcherPhase::PreInputMethod, [&](Event &event) {
            ic->commitStringImpl("你");
            Text preedit("你好");
            preedit.setCursor(3);
            ic->inputPanel().setClientPreedit(preedit);
            ic->updatePreeditImpl();
            static_cast<KeyEvent &>(event).filterAndAccept();
        });

    auto response =
        frontend.keyEvent(uuid, Key(FcitxKey_a), false, false, "", 0, 0);
    FCITX_ASSERT(response.valid);
    FCITX_ASSERT(response.outputBoundary > 0);
    FCITX_ASSERT(response.commit == "你");
    FCITX_ASSERT(response.preedit == "你好");
    FCITX_ASSERT(response.caretPos == 3);
    FCITX_ASSERT(!response.dummyPreedit);
    FCITX_ASSERT(response.accepted);

    auto compositionResponse = frontend.commitComposition(uuid);
    FCITX_ASSERT(compositionResponse.valid);
    FCITX_ASSERT(compositionResponse.commit.empty());
    FCITX_ASSERT(compositionResponse.preedit == "你好");
    FCITX_ASSERT(compositionResponse.caretPos == 3);
    FCITX_ASSERT(!compositionResponse.dummyPreedit);
    FCITX_ASSERT(!compositionResponse.accepted);
    FCITX_ASSERT(compositionResponse.outputBoundary > response.outputBoundary);

    // Popping clears commit while retaining preedit, caret and dummy flags.
    ic->setDummyPreedit(true);
    auto dummy = ic->popState(false);
    FCITX_ASSERT(dummy.valid && dummy.dummyPreedit && dummy.commit.empty());
    ic->setDummyPreedit(false);
    ic->setVimPreedit(true);
    auto vim = ic->popState(false);
    FCITX_ASSERT(vim.valid && vim.dummyPreedit && vim.preedit == "你好");
    FCITX_ASSERT(vim.caretPos == 3);

    ::pinyinKeyboard = true;
    auto punctuation = ic->popState(false, Key(FcitxKey_period));
    ::pinyinKeyboard = false;
    FCITX_ASSERT(punctuation.valid && punctuation.accepted);
    FCITX_ASSERT(punctuation.commit == ".");
    FCITX_ASSERT(ic->popState(false).commit.empty());

    frontend.destroyInputContext(uuid);
    auto missing =
        frontend.keyEvent(uuid, Key(FcitxKey_a), false, false, "", 0, 0);
    FCITX_ASSERT(!missing.valid);
    FCITX_ASSERT(!missing.accepted);
    FCITX_ASSERT(missing.outputBoundary > compositionResponse.outputBoundary);
    auto missingComposition = frontend.commitComposition(uuid);
    FCITX_ASSERT(!missingComposition.valid);
    FCITX_ASSERT(!missingComposition.accepted);
    FCITX_ASSERT(missingComposition.outputBoundary > missing.outputBoundary);
    return 0;
}
