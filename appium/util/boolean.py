from selenium.webdriver.remote.webelement import WebElement


def get_switch_state(switch: WebElement) -> bool:
    """Get the current state of a switch. True if ON, False if OFF."""
    return switch.get_attribute("value") == "1"
