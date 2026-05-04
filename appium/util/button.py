from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.message import BUTTON_SHOULD_BE_DISABLED
from util.window import find_element_by_id


def get_undo_redo(driver: WebDriver) -> tuple[WebElement, WebElement]:
    """Get undo and redo buttons, asserting they are initially disabled."""
    undo = find_element_by_id(driver, "arrow.uturn.left")
    assert is_enabled(undo) is False, BUTTON_SHOULD_BE_DISABLED

    redo = find_element_by_id(driver, "arrow.uturn.right")
    assert is_enabled(redo) is False, BUTTON_SHOULD_BE_DISABLED

    return undo, redo


def is_enabled(element: WebElement) -> bool:
    """Check if an element is enabled."""
    return element.get_attribute("enabled") == "true"
