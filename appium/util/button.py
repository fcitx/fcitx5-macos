from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from util.message import BUTTON_SHOULD_BE_DISABLED
from util.window import find_elements_by_id


def get_undo_redo(driver: WebDriver) -> tuple[WebElement, WebElement]:
    """Get undo and redo buttons, asserting they are initially disabled."""
    undo = find_elements_by_id(driver, "arrow.uturn.left")[0]
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    redo = find_elements_by_id(driver, "arrow.uturn.right")[0]
    assert redo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    return undo, redo


def get_label(button: WebElement) -> str:
    """Get the label attribute of a button."""
    return button.get_attribute("label")


def double_click(button: WebElement):
    button.parent.execute_script("macos: doubleClick", {"elementId": button.id})
