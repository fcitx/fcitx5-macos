import subprocess
import zipfile
from pathlib import Path

from appium.webdriver.webdriver import WebDriver
from util.file import select_files
from util.message import INTERNAL_TOOL_ERROR
from util.window import find_element_by_id, open_advanced_config

FCITX = "fcitx5-macos.zip"
HAMSTER = "hamster.zip"
data_path = Path(__file__).parent / "data"


def test_import_fcitx_data(driver: WebDriver, app: str):
    subprocess.run(
        ["zip", "-r", str(data_path / FCITX), "."],
        cwd=data_path / "fcitx",
        check=True,
    )
    open_advanced_config(driver)
    find_element_by_id(driver, "ImportFcitx5macOS").click()
    select_files(driver, str(data_path), [FCITX])
    find_element_by_id(driver, "Import").click()
    find_element_by_id(driver, "Done").click()

    external_path = data_path / "fcitx" / "external"
    base = Path(app).parent
    for src_path in external_path.rglob("*"):
        if src_path.is_file():
            rel = src_path.relative_to(external_path)
            target = base / rel
            assert target.exists(), INTERNAL_TOOL_ERROR


def test_import_hamster_data(driver: WebDriver, app: str):
    subprocess.run(
        ["zip", "-r", str(data_path / HAMSTER), "."],
        cwd=data_path / "hamster",
        check=True,
    )
    open_advanced_config(driver)
    find_element_by_id(driver, "ImportHamster").click()
    select_files(driver, str(data_path), [HAMSTER])
    find_element_by_id(driver, "Import").click()
    find_element_by_id(driver, "Done").click()
    assert (Path(app).parent / "data" / "rime" / "baz").exists(), INTERNAL_TOOL_ERROR


def test_export_data(driver: WebDriver, app: str):
    path = Path(app).parent
    with open(f"{app}/foo", "w"), open(path / "data" / "bar", "w"):
        pass

    open_advanced_config(driver)
    find_element_by_id(driver, "ExportFcitx5").click()
    select_files(driver, str(path), [])

    zip_path = next(path.glob("*.zip"))
    with zipfile.ZipFile(zip_path) as z:
        content = z.namelist()
    for item in ("external/config/foo", "external/data/bar", "metadata.json"):
        assert item in content, INTERNAL_TOOL_ERROR
