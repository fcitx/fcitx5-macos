from appium.webdriver.webdriver import WebDriver
from util.button import get_label
from util.config import read_theme_config
from util.message import ASSUMPTION_OUTDATED, CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.window import find_element_by_id, find_elements_by_id, open_theme_config

TEXT_FONT_FAMILY_ID = "TextFontFamily"
FONT_HELVETICA = "Helvetica"
FONT_SERIF = "serif"
FONT_EMOJI = "Apple Color Emoji"


def test_font_selection(driver: WebDriver, app: str):
    open_theme_config(driver)
    find_element_by_id(driver, "Font").click()

    def get_font_values() -> list[str]:
        return [
            get_label(element)
            for element in find_elements_by_id(driver, TEXT_FONT_FAMILY_ID)
        ]

    def read_config_value() -> dict[str, str]:
        return read_theme_config(app)[f"Font/{TEXT_FONT_FAMILY_ID}"]

    font_button = find_element_by_id(driver, TEXT_FONT_FAMILY_ID)
    font_button.click()
    emoji_elements = find_elements_by_id(driver, FONT_EMOJI)
    assert len(emoji_elements) == 1, ASSUMPTION_OUTDATED

    search = find_element_by_id(driver, "search")
    search.click()
    search.send_keys("helvetica")
    emoji_elements = find_elements_by_id(driver, FONT_EMOJI)
    assert len(emoji_elements) == 0, UI_NOT_UPDATED

    find_element_by_id(driver, FONT_HELVETICA).click()
    find_element_by_id(driver, "select").click()
    assert get_font_values() == [FONT_HELVETICA], UI_NOT_UPDATED
    assert read_config_value() == {"0": FONT_HELVETICA}, CHANGE_NOT_SAVED

    find_element_by_id(driver, f"{TEXT_FONT_FAMILY_ID}_plus").click()
    find_elements_by_id(driver, TEXT_FONT_FAMILY_ID)[1].click()
    find_element_by_id(driver, "GenericFontFamiliesTab").click()
    find_element_by_id(driver, FONT_SERIF).click()
    find_element_by_id(driver, "select").click()
    assert get_font_values() == [FONT_HELVETICA, FONT_SERIF], UI_NOT_UPDATED
    assert read_config_value() == {"0": FONT_HELVETICA, "1": FONT_SERIF}, (
        CHANGE_NOT_SAVED
    )
