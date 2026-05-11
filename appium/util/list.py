from appium.webdriver.webdriver import WebDriver
from util.window import find_element_by_id


def click_minus(driver: WebDriver, option_id: str, index: int):
    find_element_by_id(driver, f"{option_id}_{index}_minus").click()


def click_plus(driver: WebDriver, option_id: str, index: int):
    find_element_by_id(driver, f"{option_id}_{index}_plus").click()
