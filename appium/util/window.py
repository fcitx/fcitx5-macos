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


def open_global_config(driver: WebDriver) -> None:
    """Open the Global Config window."""
    btn = find_button(driver, "Global Config")
    btn.click()
