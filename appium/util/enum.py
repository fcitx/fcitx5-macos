from selenium.webdriver.remote.webelement import WebElement


def get_enum_value(picker: WebElement) -> str:
    return picker.get_attribute("value")


def select_enum_option(picker: WebElement, option_value: str) -> None:
    picker_id = picker.get_attribute("identifier")
    picker.click()
    for el in picker.find_elements(by="name", value=option_value):
        if el.get_attribute("identifier") != picker_id:
            el.click()
            break
