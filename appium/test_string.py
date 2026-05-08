from appium.webdriver.webdriver import WebDriver
from util.button import get_undo_redo, is_enabled
from util.config import read_theme_config
from util.key import press
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.string import get_string_value
from util.window import find_button, find_element_by_id, reset_option

CARET_SECTION = "Caret"
STRING_ID = "Text"


def test_theme_caret(driver: WebDriver, app: str):
    find_button(driver, "Theme").click()
    find_element_by_id(driver, CARET_SECTION).click()

    def read_config_value() -> str:
        cfg = read_theme_config(app)
        return cfg[CARET_SECTION][STRING_ID]

    field = find_element_by_id(driver, STRING_ID)
    initial_value = get_string_value(field)
    new_value = "."

    def update():
        field.click()
        field.clear()
        field.send_keys(new_value)

    update()
    undo, _ = get_undo_redo(driver)
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED

    press(driver, "\n")
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    undo.click()
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    update()
    press(driver, "\t")
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    undo.click()
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    update()
    find_element_by_id(driver, "checkmark").click()
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    reset_option(driver, STRING_ID)
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED
