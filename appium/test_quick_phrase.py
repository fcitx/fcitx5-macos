from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.button import get_label
from util.message import (
    ASSUMPTION_OUTDATED,
    BUTTON_SHOULD_BE_DISABLED,
    CHANGE_NOT_SAVED,
    INTERNAL_TOOL_ERROR,
    UI_NOT_UPDATED,
)
from util.window import (
    close_sheet,
    find_element_by_id,
    open_input_method_config,
    scroll_to,
)

BUILTIN_NAME = "emoji"


def test_builtin_quick_phrase(driver: WebDriver, app: str):
    quickphrase_dir = Path(app).parent / "data" / "data" / "quickphrase.d"
    local_file = quickphrase_dir / f"{BUILTIN_NAME}.mb"
    disabled_file = quickphrase_dir / f"{BUILTIN_NAME}.mb.disable"

    open_input_method_config(driver, "pinyin")
    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        "QuickPhrase",
    ).click()

    toggle = find_element_by_id(driver, "ToggleOrRemove")
    assert get_label(toggle) == "Disable", UI_NOT_UPDATED
    assert not local_file.exists(), ASSUMPTION_OUTDATED
    assert not disabled_file.exists(), ASSUMPTION_OUTDATED
    for button_id in ("AddItem", "RemoveItems", "Save", "OpenInEditor"):
        assert find_element_by_id(driver, button_id).is_enabled() is False, (
            BUTTON_SHOULD_BE_DISABLED
        )

    toggle.click()
    toggle = find_element_by_id(driver, "ToggleOrRemove")
    assert get_label(toggle) == "Enable", UI_NOT_UPDATED
    assert not local_file.exists(), INTERNAL_TOOL_ERROR
    assert disabled_file.read_bytes() == b"", CHANGE_NOT_SAVED

    toggle.click()
    toggle = find_element_by_id(driver, "ToggleOrRemove")
    assert get_label(toggle) == "Disable", UI_NOT_UPDATED
    assert not disabled_file.exists(), CHANGE_NOT_SAVED
    assert not local_file.exists(), INTERNAL_TOOL_ERROR

    close_sheet(driver)
