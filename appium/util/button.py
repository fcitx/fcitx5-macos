from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement


def get_undo(driver: WebDriver) -> WebElement:
    """Find the undo button by its accessibility identifier."""
    return driver.find_element(AppiumBy.ACCESSIBILITY_ID, "arrow.uturn.left")


def get_redo(driver: WebDriver) -> WebElement:
    """Find the redo button by its accessibility identifier."""
    return driver.find_element(AppiumBy.ACCESSIBILITY_ID, "arrow.uturn.right")


def is_enabled(element: WebElement) -> bool:
    """Check if an element is enabled."""
    return element.get_attribute("enabled") == "true"
