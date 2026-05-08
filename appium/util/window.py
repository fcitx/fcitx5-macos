from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.webelement import WebElement


def find_button(driver: WebDriver, label: str) -> WebElement | None:
    """Find a button by its title or label attribute."""
    buttons = driver.find_elements(By.CLASS_NAME, "XCUIElementTypeButton")
    for btn in buttons:
        title = btn.get_attribute("title") or ""
        btn_label = btn.get_attribute("label") or ""
        name = title or btn_label
        if label in name:
            return btn
    return None


def find_element_by_id(driver: WebDriver, identifier: str) -> WebElement:
    """Find an element by its accessibility identifier."""
    elements = driver.find_elements(AppiumBy.ACCESSIBILITY_ID, identifier)
    return [element for element in elements if element.tag_name == identifier][0]


def open_global_config(driver: WebDriver):
    """Open the Global Config window."""
    find_button(driver, "Global Config").click()


def open_advanced_config(driver: WebDriver):
    """Open the Advanced Config window."""
    find_button(driver, "Advanced").click()


def reset_option(driver: WebDriver, option_id: str):
    label = find_element_by_id(driver, f"{option_id}_label")
    driver.execute_script(
        "macos: rightClick",
        {
            "x": label.rect["x"] + label.rect["width"] / 2,
            "y": label.rect["y"] + label.rect["height"] / 2,
        },
    )
    find_element_by_id(driver, f"{option_id}_reset").click()
