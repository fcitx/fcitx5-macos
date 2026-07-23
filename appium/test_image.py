from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webelement import WebElement
from util.button import get_label
from util.config import read_theme_config
from util.enum import get_enum_value, select_enum_option
from util.file import select_files
from util.key import press
from util.message import ASSUMPTION_OUTDATED, CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.string import get_string_value
from util.window import find_element_by_id, open_theme_config

BACKGROUND = "Background"
PNG = "customized.png"
URL = "https://example.com/foo.png"


def test_image(driver: WebDriver, app: str):
    open_theme_config(driver)

    def read_config_value() -> str:
        return read_theme_config(app)[BACKGROUND]["ImageUrl"]

    def get_button() -> WebElement:
        return find_element_by_id(driver, "SelectImage")

    find_element_by_id(driver, BACKGROUND).click()
    mode = find_element_by_id(driver, "ImageMode")
    assert get_enum_value(mode) == "Local", ASSUMPTION_OUTDATED

    button = get_button()
    prompt_label = get_label(button)
    button.click()
    theme_path = str((Path(__file__).resolve().parent / "theme").resolve())
    select_files(driver, theme_path, [PNG])
    assert get_label(get_button()) == PNG, UI_NOT_UPDATED
    assert read_config_value() == f"fcitx:///file/img/{PNG}", CHANGE_NOT_SAVED

    find_element_by_id(driver, "ClearSelectedFile").click()
    assert get_label(get_button()) == prompt_label, UI_NOT_UPDATED
    assert read_config_value() == "", CHANGE_NOT_SAVED

    select_enum_option(mode, "URL")
    url = find_element_by_id(driver, "ImageURL")
    url.click()
    url.send_keys(URL)
    press(driver, [Keys.ENTER])
    assert get_string_value(url) == URL, UI_NOT_UPDATED
    assert read_config_value() == URL, CHANGE_NOT_SAVED
