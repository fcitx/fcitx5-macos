import shutil
import subprocess
import time
from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.config import read_config
from util.file import select_files
from util.message import CHANGE_NOT_SAVED
from util.window import find_element_by_id

table_src_path = Path(__file__).parent / "table"
plugin_path = Path(__file__).parent / "plugin"
inputmethod_path = plugin_path / "share" / "fcitx5" / "inputmethod"
table_path = plugin_path / "share" / "fcitx5" / "table"
package = "customized-any.tar.bz2"
installed_path = Path.home() / "Library/fcitx5"
installed_conf = installed_path / "share/fcitx5/inputmethod/customized.conf"
installed_dict = installed_path / "share/fcitx5/table/customized.dict"
installed_json = installed_path / "plugin/customized.json"


def wait_process_exit(name: str, timeout: float = 10):
    for _ in range(int(timeout * 10)):
        if (
            subprocess.run(
                ["pgrep", "-x", name], capture_output=True, check=False
            ).returncode
            != 0
        ):
            return
        time.sleep(0.1)
    raise TimeoutError(f"{name} did not exit within {timeout} seconds")


def test_install_manually(driver: WebDriver, app: str):
    inputmethod_path.mkdir(parents=True, exist_ok=True)
    table_path.mkdir(parents=True, exist_ok=True)
    shutil.copy(
        table_src_path / "customized.conf.in",
        inputmethod_path / "customized.conf",
    )
    subprocess.run(
        [
            str(Path.home() / "Library/fcitx5/bin/libime_tabledict"),
            f"{table_src_path / 'customized.txt'}",
            f"{table_path / 'customized.dict'}",
        ],
        check=True,
    )
    subprocess.run(
        ["tar", "-cjf", str(plugin_path / package), "plugin", "share"],
        cwd=plugin_path,
        check=True,
    )
    installed_json.unlink(missing_ok=True)
    installed_conf.unlink(missing_ok=True)
    installed_dict.unlink(missing_ok=True)

    find_element_by_id(driver, "Plugin Manager").click()
    find_element_by_id(driver, "InstallManually").click()
    select_files(driver, str(plugin_path), [package])
    wait_process_exit("FcitxTestApp")

    assert (
        installed_json.read_text()
        == (plugin_path / "plugin" / "customized.json").read_text()
    ), CHANGE_NOT_SAVED
    assert (
        installed_conf.read_text() == (inputmethod_path / "customized.conf").read_text()
    ), CHANGE_NOT_SAVED
    assert (
        installed_dict.read_bytes() == (table_path / "customized.dict").read_bytes()
    ), CHANGE_NOT_SAVED
    profile = read_config(app, "profile")
    assert profile["Groups/0/Items/1"]["Name"] == "customized", CHANGE_NOT_SAVED

    installed_json.unlink()
    installed_conf.unlink()
    installed_dict.unlink()
