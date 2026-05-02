import configparser
import os
from typing import Any


def read_config(base_path: str, filename: str) -> dict[str, Any]:
    """Read and return the deserialized INI config as a dictionary."""
    config = configparser.ConfigParser()
    config.optionxform = str
    path = os.path.join(base_path, filename)
    config.read(path)
    return {section: dict(config[section]) for section in config.sections()}
