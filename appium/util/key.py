from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.actions.action_builder import ActionBuilder


def press(driver: WebDriver, keys: list[str]):
    action = ActionBuilder(driver)
    for key in keys:
        action.key_action.key_down(key)
    for key in reversed(keys):
        action.key_action.key_up(key)
    action.perform()
