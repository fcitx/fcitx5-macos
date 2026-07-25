from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.window import find_element_by_id


def cmd_click(element: WebElement):
    element.parent.execute_script(
        "macos: click",
        {
            "elementId": element.id,
            "keyModifierFlags": 1 << 4,
        },
    )


def _click(driver: WebDriver, option_id: str, index: int, action: str):
    find_element_by_id(driver, f"{option_id}_{index}_{action}").click()


def click_minus(driver: WebDriver, option_id: str, index: int):
    _click(driver, option_id, index, "minus")


def click_plus(driver: WebDriver, option_id: str, index: int):
    _click(driver, option_id, index, "plus")


def click_up(driver: WebDriver, option_id: str, index: int):
    _click(driver, option_id, index, "up")
