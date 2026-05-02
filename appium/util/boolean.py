from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement


def get_switch(driver: WebDriver, switch_id: str) -> WebElement:
    """Find a switch by its accessibility identifier."""
    return driver.find_element(AppiumBy.ACCESSIBILITY_ID, switch_id)


def get_switch_state(switch: WebElement) -> bool:
    """Get the current state of a switch. True if ON, False if OFF."""
    value = switch.get_attribute("value")
    return value == "1"
