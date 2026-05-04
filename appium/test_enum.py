import pytest
from appium.webdriver.webdriver import WebDriver
from util.button import get_undo_redo, is_enabled
from util.config import read_config
from util.enum import get_enum_value, select_enum_option
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    CHANGE_WRONGLY_SAVED,
    UI_NOT_UPDATED,
    UI_WRONGLY_UPDATED,
)
from util.window import find_element_by_id, open_advanced_config

ADDON_ID = "chttrans"


@pytest.mark.parametrize(
    "enum_id, initial_value, initial_config_value, target_value, target_config_value",
    [
        # static enum
        ("Engine", "OpenCC", "OpenCC", "Native", "Native"),
        # dynamic enum
        ("OpenCCS2TProfile", "Default", "default", "s2t.json", "s2t.json"),
    ],
)
def test_enum_selection(
    driver: WebDriver,
    app: str,
    enum_id: str,
    initial_value: str,
    initial_config_value: str,
    target_value: str,
    target_config_value: str,
) -> None:
    open_advanced_config(driver)
    find_element_by_id(driver, ADDON_ID).click()

    def read_config_value() -> str:
        cfg = read_config(app, "conf/chttrans.conf")
        return cfg["Global"][enum_id]

    undo, redo = get_undo_redo(driver)

    picker = find_element_by_id(driver, enum_id)
    assert get_enum_value(picker) == initial_value, "Initial value mismatch"

    select_enum_option(picker, target_value)

    assert get_enum_value(picker) == target_value, UI_NOT_UPDATED
    assert read_config_value() == target_config_value, CHANGE_NOT_SAVED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED

    undo.click()
    assert get_enum_value(picker) == initial_value, UI_NOT_UPDATED
    assert read_config_value() == initial_config_value, CHANGE_NOT_SAVED
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert is_enabled(redo) is True, BUTTON_SHOULD_BE_ENABLED

    # Re-select current value
    select_enum_option(picker, initial_value)
    assert get_enum_value(picker) == initial_value, UI_WRONGLY_UPDATED
    assert read_config_value() == initial_config_value, CHANGE_WRONGLY_SAVED
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED
    assert is_enabled(redo) is True, BUTTON_SHOULD_BE_ENABLED

    redo.click()
    assert get_enum_value(picker) == target_value, UI_NOT_UPDATED
    assert read_config_value() == target_config_value, CHANGE_NOT_SAVED
    assert is_enabled(undo) is True, BUTTON_SHOULD_BE_ENABLED
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED
