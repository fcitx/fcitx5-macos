from util.message import UI_WRONGLY_UPDATED
from util.window import find_elements_by_id
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from util.button import get_undo_redo
from util.config import read_theme_config
from util.key import press
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.string import get_string_value
from util.window import find_element_by_id, open_theme_config, reset_option

CARET_SECTION = "Caret"
STRING_ID = "Text"


def test_theme_caret(driver: WebDriver, app: str):
    open_theme_config(driver)
    find_element_by_id(driver, CARET_SECTION).click()

    def read_config_value() -> str:
        cfg = read_theme_config(app)
        return cfg[CARET_SECTION][STRING_ID]

    def has_checkmark():
        return len(find_elements_by_id(driver, "checkmark")) > 0

    field = find_element_by_id(driver, STRING_ID)
    initial_value = get_string_value(field)
    new_value = "."
    assert not has_checkmark(), UI_WRONGLY_UPDATED

    def update():
        field.click()
        field.clear()
        field.send_keys(new_value)

    update()
    assert has_checkmark(), UI_NOT_UPDATED
    undo, _ = get_undo_redo(driver)
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    press(driver, [Keys.ENTER])
    assert not has_checkmark(), UI_NOT_UPDATED
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    undo.click()
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert not has_checkmark(), UI_WRONGLY_UPDATED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    update()
    press(driver, [Keys.TAB])
    assert not has_checkmark(), UI_NOT_UPDATED
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    undo.click()
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    update()
    find_element_by_id(driver, "checkmark").click()
    assert not has_checkmark(), UI_NOT_UPDATED
    assert get_string_value(field) == new_value, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    reset_option(driver, STRING_ID)
    assert not has_checkmark(), UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert get_string_value(field) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED

    # Manual revert should still be considered changed.
    field.click()
    field.send_keys("x")
    press(driver, [Keys.BACKSPACE])
    assert has_checkmark(), UI_WRONGLY_UPDATED
