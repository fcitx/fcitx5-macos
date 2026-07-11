import os
from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.file import select_files
from util.message import BUTTON_SHOULD_BE_DISABLED, CHANGE_NOT_SAVED, UI_NOT_UPDATED
from util.string import get_string_value
from util.window import find_element_by_id, find_elements_by_id


def test_import_customized_table(driver: WebDriver, app: str):
    find_element_by_id(driver, "Input Method").click()
    find_element_by_id(driver, "AddInputMethods").click()
    find_element_by_id(driver, "ImportTableTab").click()

    import_button = find_element_by_id(driver, "Import")
    assert import_button.is_enabled() is False, BUTTON_SHOULD_BE_DISABLED

    table_path = str((Path(__file__).resolve().parent / "table").resolve())
    select_files(
        driver, table_path, ["customized.conf.in", "customized.dict", "customized.txt"]
    )
    assert (
        get_string_value(find_element_by_id(driver, "SelectedFile_0"))
        == "customized.conf.in"
    ), UI_NOT_UPDATED
    assert (
        get_string_value(find_element_by_id(driver, "SelectedFile_1"))
        == "customized.dict"
    ), UI_NOT_UPDATED
    assert (
        get_string_value(find_element_by_id(driver, "SelectedFile_2"))
        == "customized.txt"
    ), UI_NOT_UPDATED

    find_elements_by_id(driver, "xmark.circle.fill")[1].click()
    assert (
        get_string_value(find_element_by_id(driver, "SelectedFile_1"))
        == "customized.txt"
    ), UI_NOT_UPDATED
    assert len(find_elements_by_id(driver, "SelectedFile_2")) == 0, UI_NOT_UPDATED

    find_element_by_id(driver, "Import").click()
    assert find_element_by_id(driver, "customized")
    expected = open(os.path.join(table_path, "customized.conf.in")).read()
    actual = open(os.path.join(app, "../data/inputmethod/customized.conf")).read()
    assert expected == actual, CHANGE_NOT_SAVED
    assert os.listdir(os.path.join(app, "../data/table")) == ["customized.main.dict"], (
        CHANGE_NOT_SAVED
    )
