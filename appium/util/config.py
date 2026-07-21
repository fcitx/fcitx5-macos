import configparser
import os
import re
from typing import Any

config_pattern = re.compile(r"^# \S+=")


def read_config(base_path: str, filename: str) -> dict[str, Any]:
    """Read and return the deserialized INI config as a dictionary."""
    config = configparser.ConfigParser()
    config.optionxform = str
    path = os.path.join(base_path, filename)
    with open(path, "r") as f:
        lines = f.readlines()
    recovered = []
    for line in lines:
        if line.startswith("# [") or config_pattern.search(line):
            recovered.append(line[2:])
        else:
            recovered.append(line)
    content = "\n".join(recovered)
    # Handle config files without section headers
    if not content.startswith("["):
        content = "[Global]\n" + content
    config.read_string(content)
    return {section: dict(config[section]) for section in config.sections()}


def read_global_config(app_config_dir: str) -> dict[str, Any]:
    """Read the global config file from the app config directory."""
    return read_config(app_config_dir, "config")


def read_theme_config(app_config_dir: str) -> dict[str, Any]:
    """Read the theme config file from the app config directory."""
    return read_config(app_config_dir, "conf/webpanel.conf")
