from appium.webdriver.webdriver import WebDriver


def press(driver: WebDriver, key: str):
    driver.execute_script("macos: keys", {"keys": [key]})
