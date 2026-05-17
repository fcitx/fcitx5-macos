from selenium.webdriver.remote.webelement import WebElement


def get_string_value(element: WebElement) -> str:
    """Get the current string value from a text field."""
    return element.get_attribute("value")


def is_focused(element: WebElement) -> bool:
    """Check if the element is focused."""
    return element.get_attribute("focused") == "true"
