from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webelement import WebElement
from util.button import double_click
from util.key import press
from util.list import cmd_click
from util.window import find_element_by_id, scroll_to


def find_open_panel_container(driver: WebDriver) -> WebElement:
    return find_element_by_id(driver, "IconView")


def select_files(driver: WebDriver, path: str, filenames: list[str]):
    """
    Empty path means keeping the default directory.
    Empty filenames means selecting a directory.
    """
    if filenames:
        find_element_by_id(driver, "square.and.arrow.down").click()
    find_open_panel_container(driver)

    if path:
        press(driver, [Keys.COMMAND, Keys.SHIFT, "H"])  # Jump to home directory.
        parts = list(Path(path).relative_to(Path.home()).parts)
        for part in parts:
            container = find_open_panel_container(driver)
            double_click(scroll_to(container, part))

    container = find_open_panel_container(driver)
    for filename in filenames:
        element = scroll_to(container, filename)
        cmd_click(element)
    find_element_by_id(driver, "OKButton").click()
