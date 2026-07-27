import os
import subprocess
from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.boolean import get_boolean_value
from util.file import select_files
from util.list import cmd_click
from util.message import (
    CHANGE_NOT_SAVED,
    INTERNAL_TOOL_ERROR,
    UI_NOT_UPDATED,
    UI_WRONGLY_UPDATED,
)
from util.window import (
    close_sheet,
    find_element_by_id,
    find_elements_by_id,
    open_input_method_config,
    scroll_to,
)

RAW = "me.txt"
BIN = "self.dict"
SG = "this.scel"
FAKE = "fake.scel"


def test_dict_manager(driver: WebDriver, app: str):
    dict_path = str((Path(__file__).resolve().parent / "dict").resolve())
    subprocess.run(
        [
            str(Path.home() / "Library/fcitx5/bin/libime_pinyindict"),
            f"{dict_path}/{RAW}",
            f"{dict_path}/{BIN}",
        ],
        check=True,
    )
    subprocess.run(
        [
            "python",
            "appium/dict/org2scel.py",
            f"{dict_path}/{RAW}",
            "-o",
            f"{dict_path}/{SG}",
        ],
        check=True,
    )
    with open(f"{dict_path}/{FAKE}", "w"):
        pass
    dictionaries_path = os.path.join(app, r"../data/pinyin/dictionaries")

    def read_dict(path: str) -> list[str]:
        with open(path) as f:
            return f.readline().strip().split()

    open_input_method_config(driver, "pinyin")
    scroll_to(
        find_element_by_id(driver, "detailScrollView"),
        "DictManager",
    ).click()
    find_element_by_id(driver, "ImportDicts").click()
    select_files(driver, dict_path, [RAW, BIN, SG, FAKE])

    expected_ids = [name.split(".")[0] for name in (RAW, BIN, SG)]
    items = []
    for expected_id in expected_ids:
        items.append(find_element_by_id(driver, expected_id))
    assert len(find_elements_by_id(driver, FAKE.split(".")[0])) == 0, UI_WRONGLY_UPDATED

    checkbox = find_element_by_id(driver, f"{BIN.split('.')[0]}_Checkbox")
    assert get_boolean_value(checkbox) is True, UI_NOT_UPDATED

    expected_files = [f"{id}.dict" for id in expected_ids]
    assert set(os.listdir(dictionaries_path)) == set(expected_files), (
        INTERNAL_TOOL_ERROR
    )

    original_dict = read_dict(f"{dict_path}/{RAW}")
    decompiled_dicts = []
    for expected_id, expected_file in zip(expected_ids, expected_files):
        tmp_path = f"{app}/../{expected_id}.txt"
        subprocess.run(
            [
                str(Path.home() / "Library/fcitx5/bin/libime_pinyindict"),
                "-d",
                f"{dictionaries_path}/{expected_file}",
                f"{tmp_path}",
            ],
            check=True,
        )
        decompiled_dicts.append(read_dict(tmp_path))
    assert decompiled_dicts[0] == original_dict, INTERNAL_TOOL_ERROR
    assert decompiled_dicts[1] == original_dict, INTERNAL_TOOL_ERROR
    # scel doesn't have frequency so normalized to 0.
    assert decompiled_dicts[2] == [original_dict[0], original_dict[1], "0"], (
        INTERNAL_TOOL_ERROR
    )

    checkbox.click()
    assert get_boolean_value(checkbox) is False, UI_NOT_UPDATED
    expected_files[1] = expected_files[1] + ".disable"
    assert set(os.listdir(dictionaries_path)) == set(expected_files), CHANGE_NOT_SAVED

    cmd_click(items[1])
    cmd_click(items[2])
    find_element_by_id(driver, "RemoveDicts").click()
    assert len(find_elements_by_id(driver, expected_ids[0])) == 1, UI_WRONGLY_UPDATED
    assert len(find_elements_by_id(driver, expected_ids[1])) == 0, UI_NOT_UPDATED
    assert len(find_elements_by_id(driver, expected_ids[2])) == 0, UI_NOT_UPDATED
    assert os.listdir(dictionaries_path) == [expected_files[0]], CHANGE_NOT_SAVED

    close_sheet(driver)
