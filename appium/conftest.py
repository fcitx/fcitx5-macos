import json
import os
import platform
import shutil
import subprocess
import time
import urllib.request
from datetime import datetime
from typing import Generator

import pytest
from appium.options.mac import Mac2Options
from appium.webdriver.webdriver import WebDriver

from appium import webdriver

APPIUM_SERVER = "http://127.0.0.1:4723"
BUNDLE_ID = "org.fcitx.FcitxTestApp"

project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def check_appium_server() -> bool:
    """Check if Appium server is running and ready."""
    try:
        with urllib.request.urlopen(f"{APPIUM_SERVER}/status", timeout=1) as resp:
            data = json.loads(resp.read())
            return data.get("value", {}).get("ready", False)
    except Exception:
        return False


def launch_app(driver: WebDriver, session_base_dir: str, test_name: str) -> str:
    """Launch the test app."""
    config_home = os.path.join(session_base_dir, test_name, "config")
    os.makedirs(config_home)
    data_home = os.path.join(session_base_dir, test_name, "data")
    os.makedirs(data_home)

    # Too many entries. Reduce to accelerate.
    if test_name == "test_punctuation_map":
        punctuation = os.path.join(data_home, "punctuation")
        mb = os.path.join(punctuation, "punc.mb.zh_CN")
        os.makedirs(punctuation)
        with open(mb, "w") as f:
            f.write(". 。\n, ，")

    if test_name == "test_custom_phrase":
        pinyin = os.path.join(data_home, "pinyin")
        custom_phrase = os.path.join(pinyin, "customphrase")
        os.makedirs(pinyin)
        with open(custom_phrase, "w") as f:
            f.write("".join(f"{chr(ord('a') + i)},{i + 1}=w{i}\n" for i in range(21)))

    profile_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profile")
    shutil.copy2(profile_src, os.path.join(config_home, "profile"))
    app_path = os.path.join(
        project_root, "build", platform.machine(), "appium/FcitxTestApp.app"
    )
    driver.execute_script(
        "macos: launchApp",
        {
            "path": app_path,
            "arguments": [],
            "environment": {
                "FCITX_CONFIG_HOME": config_home,
                "FCITX_DATA_HOME": data_home,
            },
        },
    )
    return config_home


def terminate_app(driver: WebDriver) -> None:
    """Terminate the test app."""
    driver.execute_script("macos: terminateApp", {"bundleId": BUNDLE_ID})


@pytest.fixture(scope="session")
def appium_server() -> Generator[str, None, None]:
    subprocess.run(["pkill", "-9", "FcitxTestApp"])
    """Start Appium server at session start and stop it at session end."""
    proc = subprocess.Popen(
        ["appium"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    # Wait for server to be ready (up to 5 seconds)
    for _ in range(5):
        if check_appium_server():
            break
        time.sleep(1)
    else:
        pytest.fail("Appium server did not start within 5 seconds")

    yield APPIUM_SERVER

    # Teardown: kill the Appium server
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


@pytest.fixture(scope="session")
def driver(appium_server: str) -> Generator[WebDriver, None, None]:
    """Create and teardown the Appium driver session."""
    options = Mac2Options()
    options.platform_name = "mac"
    options.automation_name = "mac2"
    drv = webdriver.Remote(appium_server, options=options)
    yield drv
    drv.quit()


@pytest.fixture(scope="session")
def session_base_dir() -> Generator[str, None, None]:
    """Create a unique base config directory for this test session."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    base_dir = os.path.join(project_root, "build/appium", timestamp)
    os.makedirs(base_dir, exist_ok=True)
    yield base_dir


@pytest.fixture(autouse=True, scope="function")
def app(
    request: pytest.FixtureRequest,
    driver: WebDriver,
    session_base_dir: str,
) -> Generator[str, None, None]:
    """Manage test app lifecycle for a single test case."""
    # Launch fresh app
    config_home = launch_app(driver, session_base_dir, request.node.name)
    yield config_home
    # Clean up after test
    terminate_app(driver)
