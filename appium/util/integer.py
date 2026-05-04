from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement


def click_stepper_increment(driver: WebDriver, stepper: WebElement) -> None:
    """Click the increment (upper) area of a vertical stepper."""
    rect = stepper.rect
    x = rect["x"] + rect["width"] / 2
    y = rect["y"] + rect["height"] * 0.25
    driver.execute_script("macos: click", {"x": x, "y": y})


def click_stepper_decrement(driver: WebDriver, stepper: WebElement) -> None:
    """Click the decrement (lower) area of a vertical stepper."""
    rect = stepper.rect
    x = rect["x"] + rect["width"] / 2
    y = rect["y"] + rect["height"] * 0.75
    driver.execute_script("macos: click", {"x": x, "y": y})


def get_integer_value(element: WebElement) -> int:
    """Get the current integer value from a text field."""
    return int(element.get_attribute("value"))
