from appium.webdriver.webdriver import WebDriver
from util.boolean import get_switch, get_switch_state
from util.button import get_redo, get_undo, is_enabled
from util.config import read_config
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.window import open_global_config

SWITCH_ID = "EnumerateWithTriggerKeys"


def test_toggle_enumerate_switch(driver: WebDriver, app: str) -> None:
    open_global_config(driver)

    undo = get_undo(driver)
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED

    redo = get_redo(driver)
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED

    switch = get_switch(driver, SWITCH_ID)
    is_on = get_switch_state(switch)
    switch.click()
    assert get_switch_state(switch) != is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED

    cfg = read_config(app, "config")
    assert cfg["Hotkey"][SWITCH_ID] == str(not is_on), CHANGE_NOT_SAVED

    undo.click()
    assert get_switch_state(switch) == is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert is_enabled(redo) is True, BUTTON_SHOULD_BE_ENABLED

    cfg = read_config(app, "config")
    assert cfg["Hotkey"][SWITCH_ID] == str(is_on), CHANGE_NOT_SAVED

    redo.click()
    assert get_switch_state(switch) != is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED

    cfg = read_config(app, "config")
    assert cfg["Hotkey"][SWITCH_ID] == str(not is_on), CHANGE_NOT_SAVED
