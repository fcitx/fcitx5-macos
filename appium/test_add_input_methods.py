from appium.webdriver.webdriver import WebDriver
from util.button import double_click
from util.config import read_config
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    LAYOUT_SHOULD_NOT_SHIFT,
    UI_NOT_UPDATED,
)
from util.window import find_element_by_id, find_elements_by_id


def test_add_input_methods(driver: WebDriver, app: str):
    find_element_by_id(driver, "Input Method").click()
    find_element_by_id(driver, "AddInputMethods").click()
    assert find_element_by_id(driver, "SelectLanguagePrompt"), UI_NOT_UPDATED

    language_list = find_element_by_id(driver, "LanguageList")
    column_width = language_list.rect["width"]
    add_button = find_element_by_id(driver, "Add")
    assert add_button.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    # Select English
    find_element_by_id(driver, "en").click()
    assert find_element_by_id(driver, "KeyboardLayoutPrompt"), UI_NOT_UPDATED
    assert find_element_by_id(driver, "LanguageList").rect["width"] == column_width, (
        LAYOUT_SHOULD_NOT_SHIFT
    )

    # Select Keyboard US
    find_element_by_id(driver, "Add:keyboard-us").click()
    assert add_button.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert find_element_by_id(driver, "KeyFn"), UI_NOT_UPDATED
    assert find_element_by_id(driver, "LanguageList").rect["width"] == column_width, (
        LAYOUT_SHOULD_NOT_SHIFT
    )

    # Add Hallelujah by double click
    hallelujah = find_element_by_id(driver, "Add:hallelujah")
    double_click(hallelujah)
    assert find_element_by_id(driver, "KeyboardLayoutPrompt"), UI_NOT_UPDATED
    assert find_element_by_id(driver, "Add").is_enabled() is False, (
        BUTTON_SHOULD_BE_DISABLED
    )
    assert len(find_elements_by_id(driver, "Add:hallelujah")) == 0, UI_NOT_UPDATED

    # Add Keyboard Us by button
    find_element_by_id(driver, "Add:keyboard-us").click()
    add_button.click()
    assert len(find_elements_by_id(driver, "LanguageList")) == 0, UI_NOT_UPDATED
    assert find_element_by_id(driver, "hallelujah"), UI_NOT_UPDATED
    assert find_element_by_id(driver, "keyboard-us"), UI_NOT_UPDATED

    profile = read_config(app, "profile")
    assert profile["Groups/0/Items/1"]["Name"] == "hallelujah", CHANGE_NOT_SAVED
    assert profile["Groups/0/Items/2"]["Name"] == "keyboard-us", CHANGE_NOT_SAVED
