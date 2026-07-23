from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.button import get_label
from util.color import get_color_value
from util.config import read_theme_config
from util.file import select_files
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.window import find_element_by_id, open_theme_config

THEME = "customized"
LIGHT_MODE = "LightMode"
HIGHLIGHT_COLOR = "HighlightColor"
VALUE = "deadbeef"


def test_user_theme(driver: WebDriver, app: str):
    open_theme_config(driver)

    def read_config_value() -> str:
        return read_theme_config(app)[LIGHT_MODE][HIGHLIGHT_COLOR].lstrip("#")

    def get_button() -> WebElement:
        return find_element_by_id(driver, "SelectTheme")

    button = get_button()
    prompt_label = get_label(button)
    button.click()
    theme_path = str((Path(__file__).resolve().parent / "theme").resolve())
    select_files(driver, theme_path, [f"{THEME}.conf"])
    assert get_label(get_button()) == THEME, UI_NOT_UPDATED
    assert read_config_value() == VALUE, CHANGE_NOT_SAVED

    find_element_by_id(driver, LIGHT_MODE).click()
    assert get_color_value(find_element_by_id(driver, HIGHLIGHT_COLOR)) == VALUE, (
        UI_NOT_UPDATED
    )

    # Theme name is not kept by design as you can adjust fields and save as new theme.
    find_element_by_id(driver, "Basic").click()
    assert get_label(get_button()) == prompt_label, UI_NOT_UPDATED
