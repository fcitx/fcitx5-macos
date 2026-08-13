from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webelement import WebElement
from util.config import read_config
from util.key import press
from util.message import UI_NOT_UPDATED, UI_WRONGLY_UPDATED
from util.window import (
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to,
)

QUICK_PHRASE_REGEX = "QuickPhraseTriggerRegex"
AUTO_SELECT_REGEX = "AutoSelectRegex"


def perform_actions(field: WebElement):
    driver = field.parent

    def has_error_message():
        return len(find_elements_by_id(driver, "InvalidRegex")) > 0

    def has_checkmark():
        return len(find_elements_by_id(driver, "checkmark")) > 0

    field.click()
    assert not has_error_message(), UI_WRONGLY_UPDATED
    assert not has_checkmark(), UI_WRONGLY_UPDATED

    press(driver, ["["])
    assert has_error_message(), UI_NOT_UPDATED
    assert not has_checkmark(), UI_WRONGLY_UPDATED

    press(driver, ["a"])
    press(driver, ["]"])
    assert not has_error_message(), UI_NOT_UPDATED
    assert has_checkmark(), UI_NOT_UPDATED

    press(driver, [Keys.RETURN])
    assert not has_error_message(), UI_WRONGLY_UPDATED
    assert not has_checkmark(), UI_NOT_UPDATED


def test_regex_list(driver: WebDriver, app: str):
    open_input_method_config(driver, "pinyin")

    def read_config_value():
        cfg = read_config(app, "conf/pinyin.conf")
        return cfg[QUICK_PHRASE_REGEX][str(len(cfg[QUICK_PHRASE_REGEX]) - 1)]

    scroll_to(find_element_by_id(driver, "detailScrollView"), QUICK_PHRASE_REGEX)
    find_element_by_id(driver, f"{QUICK_PHRASE_REGEX}_plus").click()
    field = find_elements_by_id(driver, QUICK_PHRASE_REGEX)[-1]
    perform_actions(field)
    assert read_config_value() == "[a]"


def test_regex_string(driver: WebDriver, app: str):
    open_input_method_config(driver, "wbx")

    def read_config_value():
        cfg = read_config(app, "table/wbx.conf")
        return cfg["Table"][AUTO_SELECT_REGEX]

    field = scroll_to(find_element_by_id(driver, "detailScrollView"), AUTO_SELECT_REGEX)
    perform_actions(field)
    assert read_config_value() == "[a]"
