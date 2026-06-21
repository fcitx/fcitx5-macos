from appium.webdriver.webdriver import WebDriver
from util.boolean import get_boolean_value
from util.button import get_undo_redo
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
    is_on = get_boolean_value(switch)
    switch.click()
    assert get_boolean_value(switch) != is_on, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert redo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == str(not is_on), CHANGE_NOT_SAVED

    undo.click()
    assert get_boolean_value(switch) == is_on, UI_NOT_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert redo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == str(is_on), CHANGE_NOT_SAVED

    redo.click()
    assert get_boolean_value(switch) != is_on, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert redo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == str(not is_on), CHANGE_NOT_SAVED
