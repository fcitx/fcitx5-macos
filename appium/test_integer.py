from appium.webdriver.webdriver import WebDriver
from selenium.webdriver.common.keys import Keys
from util.button import get_undo_redo
from util.config import read_global_config, read_theme_config
from util.integer import (
    click_stepper_decrement,
    click_stepper_increment,
    get_integer_value,
)
from util.key import press
from util.message import (
    BUTTON_SHOULD_BE_DISABLED,
    BUTTON_SHOULD_BE_ENABLED,
    CHANGE_NOT_SAVED,
    UI_NOT_UPDATED,
)
from util.string import get_string_value
from util.window import find_element_by_id, open_global_config, open_theme_config

INTEGER_ID = "DefaultPageSize"
INT_MAX = 10
FONT_SECTION = "Font"
FONT_WEIGHT_ID = "TextFontWeight"


def test_default_page_size(driver: WebDriver, app: str) -> None:
    open_global_config(driver)
    find_element_by_id(driver, "Behavior").click()

    def read_config_value() -> str:
        cfg = read_global_config(app)
        return cfg["Behavior"][INTEGER_ID]

    undo, redo = get_undo_redo(driver)

    field = find_element_by_id(driver, INTEGER_ID)
    initial_value = get_integer_value(field)

    stepper = find_element_by_id(driver, f"{INTEGER_ID}_stepper")
    click_stepper_increment(driver, stepper)

    new_value = get_integer_value(field)
    assert new_value == initial_value + 1, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert redo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    assert read_config_value() == str(new_value), CHANGE_NOT_SAVED

    undo.click()
    undo_value = get_integer_value(field)
    assert undo_value == initial_value, UI_NOT_UPDATED
    assert undo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert redo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED

    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED

    redo.click()
    redo_value = get_integer_value(field)
    assert redo_value == initial_value + 1, UI_NOT_UPDATED
    assert undo.is_enabled() is True, BUTTON_SHOULD_BE_ENABLED
    assert redo.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED
    assert read_config_value() == str(redo_value), CHANGE_NOT_SAVED

    click_stepper_decrement(driver, stepper)
    final_value = get_integer_value(field)
    assert final_value == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(final_value), CHANGE_NOT_SAVED

    # Test non-numeric input
    field.click()
    field.clear()
    field.send_keys("x")
    assert get_string_value(field) == "x", UI_NOT_UPDATED
    press(driver, [Keys.ENTER])
    assert get_integer_value(field) == initial_value, UI_NOT_UPDATED

    # Test input validation: Enter value exceeding max (10)
    field.click()
    field.clear()
    field.send_keys("100")
    # Click elsewhere to trigger blur validation
    find_element_by_id(driver, "Behavior").click()
    clamped_value = get_integer_value(field)
    assert clamped_value == INT_MAX, (
        f"Value should be clamped to {INT_MAX}, got {clamped_value}"
    )
    assert read_config_value() == str(INT_MAX), CHANGE_NOT_SAVED

    # Test ResetPage
    find_element_by_id(driver, "ResetPage").click()
    reset_value = get_integer_value(field)
    assert reset_value == initial_value, UI_NOT_UPDATED
    assert read_config_value() == str(initial_value), CHANGE_NOT_SAVED


def test_font_weight(driver: WebDriver, app: str) -> None:
    open_theme_config(driver)
    find_element_by_id(driver, FONT_SECTION).click()

    def read_config_value() -> str:
        cfg = read_theme_config(app)
        return cfg[FONT_SECTION][FONT_WEIGHT_ID]

    field = find_element_by_id(driver, FONT_WEIGHT_ID)
    stepper = find_element_by_id(driver, f"{FONT_WEIGHT_ID}_stepper")

    def set_value(value: str) -> None:
        field.click()
        field.clear()
        field.send_keys(value)
        press(driver, [Keys.ENTER])

    def assert_value(value: int) -> None:
        assert get_integer_value(field) == value, UI_NOT_UPDATED
        assert read_config_value() == str(value), CHANGE_NOT_SAVED

    set_value("950")
    assert_value(950)

    click_stepper_increment(driver, stepper)
    assert_value(1000)

    click_stepper_decrement(driver, stepper)
    assert_value(900)

    click_stepper_decrement(driver, stepper)
    assert_value(800)

    set_value("50")
    assert_value(50)

    click_stepper_decrement(driver, stepper)
    assert_value(1)

    click_stepper_increment(driver, stepper)
    assert_value(100)

    click_stepper_increment(driver, stepper)
    assert_value(200)
