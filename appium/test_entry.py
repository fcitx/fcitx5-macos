import os

from appium.webdriver.webdriver import WebDriver
from util.button import get_undo_redo
from util.key import press
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED, UI_WRONGLY_UPDATED
from util.string import get_string_value, is_focused
from util.window import (
    close_sheet,
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to,
)

KEY = "Key"
MAPPING = "Mapping"
ALT_MAPPING = "AltMapping"


def test_punctuation_map(driver: WebDriver, app: str) -> None:
    open_input_method_config(driver, "pinyin")
    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        "Punctuation",
    )
    punctuation = find_element_by_id(driver, "Punctuation")
    punctuation.click()

    def read_config_value() -> str:
        punc_path = os.path.join(app, r"../data/punctuation/punc.mb.zh_CN")
        with open(punc_path, "r") as f:
            return f.readline().strip()

    undo, _ = get_undo_redo(driver)
    key = find_elements_by_id(driver, KEY)[0]
    assert is_focused(key), UI_NOT_UPDATED

    key.send_keys("*")
    press(driver, ["\t"])
    mapping = find_elements_by_id(driver, MAPPING)[0]
    assert is_focused(mapping), UI_WRONGLY_UPDATED
    # Shouldn't trigger rerender so reuse key.
    assert get_string_value(key) == "*", UI_WRONGLY_UPDATED
    assert read_config_value() == "* 。", CHANGE_NOT_SAVED

    mapping.send_keys(r"\times")
    alt_mapping = find_elements_by_id(driver, ALT_MAPPING)[0]
    alt_mapping.click()
    assert get_string_value(key) == "*", UI_WRONGLY_UPDATED
    assert get_string_value(mapping) == r"\times", UI_WRONGLY_UPDATED
    assert read_config_value() == r"* \times", CHANGE_NOT_SAVED
    assert is_focused(alt_mapping), UI_WRONGLY_UPDATED

    alt_mapping.send_keys(r"\dot")
    press(driver, ["\n"])
    assert get_string_value(key) == "*", UI_WRONGLY_UPDATED
    assert get_string_value(mapping) == r"\times", UI_WRONGLY_UPDATED
    assert get_string_value(alt_mapping) == r"\dot", UI_WRONGLY_UPDATED
    assert read_config_value() == r"* \times \dot", CHANGE_NOT_SAVED

    undo.click()
    assert get_string_value(find_elements_by_id(driver, KEY)[0]) == "*", (
        UI_WRONGLY_UPDATED
    )
    assert get_string_value(find_elements_by_id(driver, MAPPING)[0]) == r"\times", (
        UI_WRONGLY_UPDATED
    )
    assert get_string_value(find_elements_by_id(driver, ALT_MAPPING)[0]) == "", (
        UI_NOT_UPDATED
    )
    assert read_config_value() == r"* \times", CHANGE_NOT_SAVED
    close_sheet(driver)
