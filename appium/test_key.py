from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from util.button import get_undo_redo
from util.config import read_global_config
from util.key import get_label, press
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
    UI_WRONGLY_UPDATED,
)
from util.window import find_element_by_id, find_elements_by_id, open_global_config

KEY_ID = "TriggerKeys"
INDEX = 0
# XXX: [Keys.CONTROL, Keys.RIGHT_SHIFT] is recognized as Ctrl+LSHIFT.
KEYS = [Keys.CONTROL, Keys.SHIFT, "A"]
KEYS_LABEL = "⌃⇧A"
KEYS_VALUE = "Control+Shift+A"


def test_record_shortcut(driver: WebDriver, app: str):
    open_global_config(driver)

    def read_config_value() -> str:
        cfg = read_global_config(app)
        return cfg[f"Hotkey/{KEY_ID}"][str(INDEX)]

    button = find_elements_by_id(driver, KEY_ID)[INDEX]
    initial_label = get_label(button)
    undo, _ = get_undo_redo(driver)

    def update():
        button.click()
        press(driver, KEYS)
        assert (
            find_element_by_id(driver, f"{KEY_ID}_key").get_attribute("value")
            == KEYS_LABEL
        ), UI_NOT_UPDATED

    update()
    find_element_by_id(driver, f"{KEY_ID}_cancel").click()
    assert get_label(button) == initial_label, UI_WRONGLY_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    update()
    find_element_by_id(driver, f"{KEY_ID}_ok").click()
    button = find_elements_by_id(driver, KEY_ID)[0]
    assert get_label(button) == KEYS_LABEL, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == KEYS_VALUE, CHANGE_NOT_SAVED

    undo.click()
    button = find_elements_by_id(driver, KEY_ID)[0]
    assert get_label(button) == initial_label, UI_NOT_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() != KEYS_VALUE, CHANGE_NOT_SAVED
