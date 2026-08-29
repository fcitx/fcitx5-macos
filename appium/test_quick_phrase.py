from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.button import get_label
from util.enum import select_enum_option
from util.integer import get_integer_value
from util.message import (
    ASSUMPTION_OUTDATED,
    BUTTON_SHOULD_BE_DISABLED,
    CHANGE_NOT_SAVED,
    INTERNAL_TOOL_ERROR,
    UI_NOT_UPDATED,
)
from util.string import get_string_value
from util.window import (
    close_sheet,
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to,
)

BUILTIN_NAME = "emoji-eac"
PAGE_SIZE = 10
GLOBAL_QUICKPHRASE_DIR = Path(
    "/Library/Input Methods/Fcitx5.app/Contents/share/fcitx5/data/quickphrase.d"
)
CUSTOM_NAME = "test"


def _open_quick_phrase(driver: WebDriver) -> None:
    open_input_method_config(driver, "pinyin")
    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        "QuickPhrase",
    ).click()


def test_builtin_quick_phrase(driver: WebDriver, app: str):
    quickphrase_dir = Path(app).parent / "data" / "data" / "quickphrase.d"
    local_file = quickphrase_dir / f"{BUILTIN_NAME}.mb"
    disabled_file = quickphrase_dir / f"{BUILTIN_NAME}.mb.disable"
    builtin_file = GLOBAL_QUICKPHRASE_DIR / f"{BUILTIN_NAME}.mb"
    item_count = sum(
        len(line.split(maxsplit=1)) == 2
        for line in builtin_file.read_text().splitlines()
    )
    expected_pages = max(1, (item_count + PAGE_SIZE - 1) // PAGE_SIZE)

    _open_quick_phrase(driver)
    select_enum_option(find_element_by_id(driver, "QuickPhraseFile"), BUILTIN_NAME)

    previous_page = find_element_by_id(driver, "chevron.left")
    next_page = find_element_by_id(driver, "chevron.right")
    page = find_element_by_id(driver, "Page")
    total_pages = find_element_by_id(driver, "TotalPages")
    assert get_integer_value(page) == 1, UI_NOT_UPDATED
    assert get_string_value(total_pages) == f"/ {expected_pages}", UI_NOT_UPDATED
    assert len(find_elements_by_id(driver, "Keyword")) == min(PAGE_SIZE, item_count), (
        UI_NOT_UPDATED
    )
    assert previous_page.is_enabled() is False, UI_NOT_UPDATED
    assert next_page.is_enabled() is (expected_pages > 1), UI_NOT_UPDATED
    if expected_pages > 1:
        next_page.click()
        assert get_integer_value(page) == 2, UI_NOT_UPDATED

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
    assert get_integer_value(find_element_by_id(driver, "Page")) == 1, UI_NOT_UPDATED
    assert not local_file.exists(), INTERNAL_TOOL_ERROR
    assert disabled_file.read_bytes() == b"", CHANGE_NOT_SAVED

    toggle.click()
    toggle = find_element_by_id(driver, "ToggleOrRemove")
    assert get_label(toggle) == "Disable", UI_NOT_UPDATED
    assert not disabled_file.exists(), CHANGE_NOT_SAVED
    assert not local_file.exists(), INTERNAL_TOOL_ERROR

    close_sheet(driver)


def test_create_quick_phrase_file(driver: WebDriver, app: str):
    quickphrase_dir = Path(app).parent / "data" / "data" / "quickphrase.d"
    custom_file = quickphrase_dir / f"{CUSTOM_NAME}.mb"

    assert not custom_file.exists(), ASSUMPTION_OUTDATED
    _open_quick_phrase(driver)

    find_element_by_id(driver, "NewFile").click()
    name = find_element_by_id(driver, "NewFileName")
    name.click()
    name.send_keys(CUSTOM_NAME)
    find_element_by_id(driver, "CreateFile").click()

    assert custom_file.read_bytes() == b"", CHANGE_NOT_SAVED
    toggle = find_element_by_id(driver, "ToggleOrRemove")
    assert get_label(toggle) == "Remove", UI_NOT_UPDATED

    find_element_by_id(driver, "AddItem").click()
    keyword = find_element_by_id(driver, "Keyword")
    keyword.click()
    keyword.send_keys("foo")
    phrase = find_element_by_id(driver, "Phrase")
    phrase.click()
    phrase.send_keys("bar")
    find_element_by_id(driver, "Save").click()

    assert custom_file.read_text() == "foo bar\n", CHANGE_NOT_SAVED
    assert get_string_value(find_element_by_id(driver, "Keyword")) == "foo", (
        UI_NOT_UPDATED
    )
    assert get_string_value(find_element_by_id(driver, "Phrase")) == "bar", (
        UI_NOT_UPDATED
    )

    find_element_by_id(driver, "ToggleOrRemove").click()
    assert not custom_file.exists(), CHANGE_NOT_SAVED
    close_sheet(driver)
