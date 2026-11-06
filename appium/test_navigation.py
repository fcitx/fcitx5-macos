from collections.abc import Callable

import pytest
from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from util.key import press
from util.message import UI_NOT_UPDATED
from util.window import find_element_by_id, open_global_config, open_theme_config


@pytest.mark.parametrize(
    "open_config, section",
    [(open_global_config, "Hotkey"), (open_theme_config, "Font")],
    ids=["global", "theme"],
)
def test_sidebar_keyboard_navigation(
    driver: WebDriver, open_config: Callable[[WebDriver], None], section: str
) -> None:
    open_config(driver)
    find_element_by_id(driver, section).click()

    def selection() -> list[str]:
        rows = driver.find_elements(AppiumBy.XPATH, "//XCUIElementTypeOutlineRow")
        return [row.get_attribute("selected") for row in rows]

    initial = selection()
    for _ in range(2):
        press(driver, [Keys.ARROW_DOWN])
        assert selection() != initial, UI_NOT_UPDATED
        press(driver, [Keys.ARROW_UP])
        assert selection() == initial, UI_NOT_UPDATED
