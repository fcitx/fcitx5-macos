from selenium.webdriver.remote.webelement import WebElement


def get_string_value(element: WebElement) -> str:
    """Get the current string value from a text field."""
    return element.get_attribute("value")
