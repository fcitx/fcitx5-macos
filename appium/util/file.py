from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webelement import WebElement
from util.key import press
from util.window import find_element_by_id, scroll_to


def find_open_panel_container(driver: WebDriver) -> WebElement:
    return find_element_by_id(driver, "IconView")


def select_files(driver: WebDriver, path: str, filenames: list[str]):
    """
    Empty path means keeping the default directory.
    """
    find_element_by_id(driver, "square.and.arrow.down").click()
    find_open_panel_container(driver)
    open_button = find_element_by_id(driver, "OKButton")

    if path:
        press(driver, [Keys.COMMAND, Keys.SHIFT, "H"])  # Jump to home directory.
        parts = list(Path(path).relative_to(Path.home()).parts)
        for part in parts:
            container = find_open_panel_container(driver)
            element = scroll_to(container, part)
            element.click()
            open_button.click()

    container = find_open_panel_container(driver)
    for filename in filenames:
        element = scroll_to(container, filename)
        driver.execute_script(
            "macos: click",
            {
                "elementId": element.id,
                "keyModifierFlags": 1 << 4,
            },
        )
    open_button.click()
