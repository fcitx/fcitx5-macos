from selenium.webdriver.remote.webelement import WebElement


def get_boolean_value(switch: WebElement) -> bool:
    """Get the current state of a switch or checkbox. True if ON, False if OFF."""
    return switch.get_attribute("value") == "1"
