from appium.webdriver.webdriver import WebDriver
from util.button import get_undo_redo
from util.color import get_color_value, set_color_value
from util.config import read_theme_config
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.window import find_element_by_id, open_theme_config

LIGHT_SECTION = "LightMode"
COLOR_ID = "HighlightColor"


def test_highlight_color(driver: WebDriver, app: str):
    open_theme_config(driver)
    find_element_by_id(driver, LIGHT_SECTION).click()

    def read_config_value() -> str:
        cfg = read_theme_config(app)
        return cfg[LIGHT_SECTION][COLOR_ID].lstrip("#")

    field = find_element_by_id(driver, COLOR_ID)
    initial_value = get_color_value(field)
    new_value = "abcdef"
    undo, _ = get_undo_redo(driver)

    set_color_value(field, new_value)
    assert get_color_value(field) == new_value, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert read_config_value() == new_value, CHANGE_NOT_SAVED

    undo.click()
    assert get_color_value(field) == initial_value, UI_NOT_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == initial_value, CHANGE_NOT_SAVED
