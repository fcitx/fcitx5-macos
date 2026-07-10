from appium.webdriver.webdriver import WebDriver
from util.boolean import get_boolean_value
from util.config import read_config
from util.message import (
    CHANGE_NOT_SAVED,
    CHANGE_WRONGLY_SAVED,
    UI_NOT_UPDATED,
    UI_WRONGLY_UPDATED,
)
from util.window import (
    find_element_by_id,
    open_input_method_config,
    reset_option,
    scroll_to,
)

FUZZY = "Fuzzy"
SWITCH_IDS = ["VAsQuickphrase", "VE_UE", "NG_GN"]


def test_reset_group(driver: WebDriver, app: str):
    open_input_method_config(driver, "pinyin")

    def read_config_values() -> list[str]:
        cfg = read_config(app, "conf/pinyin.conf")
        return [
            cfg["Global"][SWITCH_IDS[0]],
            cfg[FUZZY][SWITCH_IDS[1]],
            cfg[FUZZY][SWITCH_IDS[2]],
        ]

    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        SWITCH_IDS[0],
    )

    for switch_id in SWITCH_IDS:
        find_element_by_id(driver, switch_id).click()
    toggled = read_config_values()
    toggled_ui = [
        get_boolean_value(find_element_by_id(driver, id)) for id in SWITCH_IDS
    ]

    reset_option(driver, FUZZY)
    for i, switch_id in enumerate(SWITCH_IDS):
        ui_state = get_boolean_value(find_element_by_id(driver, switch_id))
        if i == 0:
            assert ui_state == toggled_ui[i], UI_WRONGLY_UPDATED
        else:
            assert ui_state != toggled_ui[i], UI_NOT_UPDATED

    after_reset = read_config_values()
    assert after_reset[0] == toggled[0], CHANGE_WRONGLY_SAVED
    assert after_reset[1] != toggled[1], CHANGE_NOT_SAVED
    assert after_reset[2] != toggled[2], CHANGE_NOT_SAVED
