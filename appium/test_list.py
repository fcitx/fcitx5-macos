from appium.webdriver.webdriver import WebDriver
from util.button import get_label, get_undo_redo
from util.config import read_config, read_global_config
from util.enum import get_enum_value, select_enum_option
from util.list import click_minus, click_plus, click_up
from util.message import (
    ASSUMPTION_OUTDATED,
    BUTTON_SHOULD_BE_DISABLED,
    CHANGE_NOT_SAVED,
    CONTENT_MISMATCH,
    UI_NOT_UPDATED,
)
from util.window import (
    find_element_by_id,
    find_elements_by_id,
    open_advanced_config,
    open_global_config,
    reset_option,
)

PROVIDER_ORDER = "ProviderOrder"
ALT_TRIGGER_KEYS = "AltTriggerKeys"


def test_spell_backend_list(driver: WebDriver, app: str):
    open_advanced_config(driver)
    find_element_by_id(driver, "spell").click()

    def get_provider_values() -> list[str]:
        return [
            get_enum_value(picker)
            for picker in find_elements_by_id(driver, PROVIDER_ORDER)
        ]

    def read_config_value() -> dict[str, str]:
        return read_config(app, "conf/spell.conf")[PROVIDER_ORDER]

    undo, redo = get_undo_redo(driver)
    provider_values = get_provider_values()
    assert len(provider_values) == 3, ASSUMPTION_OUTDATED

    click_minus(driver, PROVIDER_ORDER, 1)
    removed = provider_values.pop(1)
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    config_after_minus = read_config_value()

    click_plus(driver, PROVIDER_ORDER, 0)
    provider_values.insert(0, "")
    assert get_provider_values() == provider_values, UI_NOT_UPDATED

    select_enum_option(find_elements_by_id(driver, PROVIDER_ORDER)[0], removed)
    provider_values[0] = removed
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    config_after_plus = read_config_value()
    first_in_plus = config_after_plus.pop("0")
    assert config_after_plus == {
        "1": config_after_minus["0"],
        "2": config_after_minus["1"],
    }, CHANGE_NOT_SAVED

    undo.click()
    undo.click()
    provider_values.pop(0)
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    assert read_config_value() == config_after_minus, CHANGE_NOT_SAVED

    undo.click()
    provider_values.insert(1, removed)
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == {
        "0": config_after_minus["0"],
        "1": first_in_plus,
        "2": config_after_minus["1"],
    }, CHANGE_NOT_SAVED

    redo.click()
    provider_values.pop(1)
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    assert read_config_value() == config_after_minus, CHANGE_NOT_SAVED

    click_up(driver, PROVIDER_ORDER, 1)
    provider_values.reverse()
    assert get_provider_values() == provider_values, UI_NOT_UPDATED
    assert read_config_value() == {
        "0": config_after_minus["1"],
        "1": config_after_minus["0"],
    }, CHANGE_NOT_SAVED


def test_clear_list_and_reset(driver: WebDriver, app: str):
    def count() -> int:
        return len(find_elements_by_id(driver, ALT_TRIGGER_KEYS))

    open_global_config(driver)
    assert count() == 1, ASSUMPTION_OUTDATED
    label = get_label(find_element_by_id(driver, ALT_TRIGGER_KEYS))

    click_minus(driver, ALT_TRIGGER_KEYS, 0)
    assert count() == 0, UI_NOT_UPDATED
    assert read_global_config(app)["Hotkey"][ALT_TRIGGER_KEYS] == "", CHANGE_NOT_SAVED

    reset_option(driver, ALT_TRIGGER_KEYS)
    assert count() == 1, UI_NOT_UPDATED
    assert get_label(find_element_by_id(driver, ALT_TRIGGER_KEYS)) == label, (
        CONTENT_MISMATCH
    )
    assert len(read_global_config(app)[f"Hotkey/{ALT_TRIGGER_KEYS}"]) == 1, (
        CHANGE_NOT_SAVED
    )
