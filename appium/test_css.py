import os
import shutil
from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.button import get_label
from util.config import read_theme_config
from util.file import select_files
from util.message import CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.window import find_element_by_id, open_theme_config

ADVANCED = "Advanced"
CSS = "customized.css"
ANOTHER = "another.css"


def test_css(driver: WebDriver, app: str):
    open_theme_config(driver)

    def read_config_value() -> str:
        return read_theme_config(app)[ADVANCED]["UserCss"]

    find_element_by_id(driver, ADVANCED).click()
    button = find_element_by_id(driver, "SelectCss")
    prompt_label = get_label(button)
    button.click()
    theme_path = str((Path(__file__).resolve().parent / "theme").resolve())
    select_files(driver, theme_path, [CSS])
    assert get_label(button) == CSS, UI_NOT_UPDATED
    assert read_config_value() == f"fcitx:///file/css/{CSS}", CHANGE_NOT_SAVED
    css_dir = os.path.join(app, "../data/www/css")
    assert os.listdir(css_dir) == [CSS], CHANGE_NOT_SAVED

    find_element_by_id(driver, "ClearSelectedFile").click()
    assert get_label(button) == prompt_label, UI_NOT_UPDATED
    assert read_config_value() == "", CHANGE_NOT_SAVED

    shutil.copy(os.path.join(css_dir, CSS), os.path.join(css_dir, ANOTHER))
    button.click()
    select_files(driver, "", [ANOTHER])
    assert get_label(button) == ANOTHER, UI_NOT_UPDATED
    assert read_config_value() == f"fcitx:///file/css/{ANOTHER}", CHANGE_NOT_SAVED
