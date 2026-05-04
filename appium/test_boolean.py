from appium.webdriver.webdriver import WebDriver
from util.boolean import get_switch_state
from util.button import get_undo_redo, is_enabled
from util.config import read_global_config
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.window import find_element_by_id, open_global_config

SWITCH_ID = "EnumerateWithTriggerKeys"


def test_toggle_enumerate_switch(driver: WebDriver, app: str) -> None:
    open_global_config(driver)

    def read_config_value() -> str:
        cfg = read_global_config(app)
        return cfg["Hotkey"][SWITCH_ID]

    undo, redo = get_undo_redo(driver)

    switch = find_element_by_id(driver, SWITCH_ID)
    is_on = get_switch_state(switch)
    switch.click()
    assert get_switch_state(switch) != is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == str(not is_on), CHANGE_NOT_SAVED

    undo.click()
    assert get_switch_state(switch) == is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert is_enabled(redo) is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == str(is_on), CHANGE_NOT_SAVED

    redo.click()
    assert get_switch_state(switch) != is_on, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == str(not is_on), CHANGE_NOT_SAVED
