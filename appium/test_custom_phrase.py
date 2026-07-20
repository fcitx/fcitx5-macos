import os

from appium.webdriver.webdriver import WebDriver
from util.boolean import get_boolean_value
from util.button import double_click
from util.integer import get_integer_value
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED, UI_WRONGLY_UPDATED
from util.string import get_string_value
from util.window import (
    close_sheet,
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to,
)


def test_custom_phrase(driver: WebDriver, app: str):
    custom_phrase_path = os.path.join(app, r"../data/pinyin/customphrase")

    def read_config_value() -> str:
        with open(custom_phrase_path, "r") as f:
            return f.read()

    open_input_method_config(driver, "pinyin")
    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        "CustomPhrase",
    )
    find_element_by_id(driver, "CustomPhrase").click()
    j = find_elements_by_id(driver, "Keyword")[-1]
    w9 = find_elements_by_id(driver, "Phrase")[-1]
    o10 = find_elements_by_id(driver, "Order")[-1]
    assert get_string_value(j) == "j", UI_NOT_UPDATED
    assert get_string_value(w9) == "w9", UI_NOT_UPDATED
    assert get_integer_value(o10) == 10, UI_NOT_UPDATED
    prev_button = find_element_by_id(driver, "chevron.left")
    next_button = find_element_by_id(driver, "chevron.right")
    assert prev_button.is_enabled() is False, UI_NOT_UPDATED
    assert next_button.is_enabled() is True, UI_NOT_UPDATED
    page = find_element_by_id(driver, "Page")
    assert get_integer_value(page) == 1, UI_NOT_UPDATED
    total_pages = find_element_by_id(driver, "TotalPages")
    assert get_string_value(total_pages) == "/ 3", UI_NOT_UPDATED

    next_button.click()
    t = find_elements_by_id(driver, "Keyword")[-1]
    assert get_string_value(t) == "t", UI_NOT_UPDATED
    assert get_integer_value(page) == 2, UI_NOT_UPDATED
    assert get_string_value(total_pages) == "/ 3", UI_WRONGLY_UPDATED
    assert prev_button.is_enabled() is True, UI_NOT_UPDATED
    assert next_button.is_enabled() is True, UI_WRONGLY_UPDATED

    page.click()
    page.clear()
    page.send_keys("3")
    u = find_element_by_id(driver, "Keyword")
    assert get_string_value(u) == "u", UI_NOT_UPDATED
    assert get_integer_value(page) == 3, UI_NOT_UPDATED
    assert get_string_value(total_pages) == "/ 3", UI_WRONGLY_UPDATED
    assert prev_button.is_enabled() is True, UI_WRONGLY_UPDATED
    assert next_button.is_enabled() is False, UI_NOT_UPDATED

    u.click()
    find_element_by_id(driver, "RemoveItems").click()
    t = find_elements_by_id(driver, "Keyword")[-1]
    assert get_string_value(t) == "t", UI_NOT_UPDATED
    assert get_integer_value(page) == 2, UI_NOT_UPDATED
    assert get_string_value(total_pages) == "/ 2", UI_NOT_UPDATED
    assert next_button.is_enabled() is False, UI_NOT_UPDATED

    add_item = find_element_by_id(driver, "AddItem")
    add_item.click()
    assert get_integer_value(page) == 3, UI_NOT_UPDATED
    assert get_string_value(total_pages) == "/ 3", UI_NOT_UPDATED

    v = find_element_by_id(driver, "Keyword")
    v.click()
    v.send_keys("v")
    w21 = find_element_by_id(driver, "Phrase")
    w21.click()
    w21.send_keys("w21")
    o22 = find_element_by_id(driver, "Order")
    double_click(o22)
    o22.clear()
    o22.send_keys("22")
    checkbox = find_element_by_id(driver, "Checkbox")
    checkbox.click()
    assert get_boolean_value(checkbox) is False, UI_NOT_UPDATED

    add_item.click()
    old_config = read_config_value()
    find_element_by_id(driver, "Save").click()
    new_config = read_config_value()
    assert new_config == old_config.replace("u,21=w20", "v,-22=w21"), CHANGE_NOT_SAVED

    with open(custom_phrase_path, "w") as f:
        f.write("foo,2=bar")
    find_element_by_id(driver, "Reload").click()
    foo = find_element_by_id(driver, "Keyword")
    bar = find_element_by_id(driver, "Phrase")
    two = find_element_by_id(driver, "Order")
    assert get_string_value(foo) == "foo", UI_NOT_UPDATED
    assert get_string_value(bar) == "bar", UI_NOT_UPDATED
    assert get_integer_value(two) == 2, UI_NOT_UPDATED

    close_sheet(driver)
    assert len(find_elements_by_id(driver, "Keyword")) == 0, UI_NOT_UPDATED
