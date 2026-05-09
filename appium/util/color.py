from selenium.webdriver.remote.webelement import WebElement
from appium.webdriver.common.appiumby import AppiumBy
from util.key import press
from util.window import find_element_by_id


def get_color_value(element: WebElement) -> str:
    """Get the current color value from a text element."""
    raw = element.get_attribute("value")  # rgb 0.0705882 0.203922 0.337255 1
    return "".join(
        "%.2x" % round(float(x) * 255) for x in raw.split()[1:-1]
    )  # ignore alpha


def set_color_value(element: WebElement, value: str):
    driver = element.parent
    element.click()

    # Slider mode
    buttons = driver.find_elements(AppiumBy.CLASS_NAME, "XCUIElementTypeButton")
    for button in buttons:
        if button.get_attribute("label") == "Color Sliders":
            button.click()
            break

    # RGB slider
    button = driver.find_element(AppiumBy.CLASS_NAME, "XCUIElementTypePopUpButton")
    button.click()
    find_element_by_id(driver, "showRGBView:").click()

    # Type hex
    hex_field = find_element_by_id(driver, "hex")
    hex_field.send_keys(value)
    press(driver, "\n")  # Without it, below may throw StaleElementReferenceException.

    # Close
    buttons = driver.find_elements(AppiumBy.CLASS_NAME, "XCUIElementTypeButton")
    for button in buttons:
        if (
            button.tag_name == "_XCUI:CloseWindow"
            and button.size["height"] == 12
            and button.size["width"] == 12
        ):
            button.click()
            break
