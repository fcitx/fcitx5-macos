from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement


def find_element_by_id(driver: WebDriver, identifier: str) -> WebElement:
    """Find an element by its accessibility identifier."""
    elements = driver.find_elements(AppiumBy.ACCESSIBILITY_ID, identifier)
    return [element for element in elements if element.tag_name == identifier][0]


def open_global_config(driver: WebDriver):
    """Open the Global Config window."""
    find_element_by_id(driver, "Global Config").click()


def open_theme_config(driver: WebDriver):
    """Open the Theme window."""
    find_element_by_id(driver, "Theme").click()


def open_advanced_config(driver: WebDriver):
    """Open the Advanced Config window."""
    find_element_by_id(driver, "Advanced").click()


def reset_option(driver: WebDriver, option_id: str):
    label = find_element_by_id(driver, f"{option_id}_label")
    driver.execute_script(
        "macos: rightClick",
        {
            "x": label.rect["x"] + label.rect["width"] / 2,
            "y": label.rect["y"] + label.rect["height"] / 2,
        },
    )
    find_element_by_id(driver, f"{option_id}_reset").click()
