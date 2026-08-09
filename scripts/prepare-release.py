import json
import os
import re
import subprocess
import sys

from common import ScriptError, dollar, get_json


def get_version():
    project_line = dollar('grep "project(fcitx5-macos VERSION" CMakeLists.txt')
    match = re.search(r"VERSION ([\d\.]+)", project_line)
    if match is None:
        raise ScriptError("CMakeLists.txt should set VERSION properly.")
    return match.group(1)


def main():
    if dollar("git rev-parse --abbrev-ref HEAD") != "master":
        raise ScriptError("Releases must be made from the master branch.")

    next_version = sys.argv[1] if len(sys.argv) > 1 else None
    version = get_version()
    if (
        subprocess.run(
            f'git tag -a {version} -m "release {version}"', shell=True, check=False
        ).returncode
        != 0
    ):
        raise ScriptError("Failed to create git tag.")

    with open("version.jsonl") as f:
        content = f.read()

    with open("version.jsonl", "w") as f:
        json.dump(get_json(version), f)
        f.write("\n" + content)

    if next_version is None:
        major, minor, patch = version.split(".")
        next_version = f"{major}.{minor}.{int(patch) + 1}"

    if (
        subprocess.run(
            f'sed -i.bak "s/fcitx5-macos VERSION {re.escape(version)}/fcitx5-macos VERSION {next_version}/" CMakeLists.txt',
            shell=True,
            check=False,
        ).returncode
        != 0
    ):
        raise ScriptError("Failed to update version in CMakeLists.txt.")
    os.remove("CMakeLists.txt.bak")

    subprocess.run("git add version.jsonl CMakeLists.txt", shell=True, check=False)


if __name__ == "__main__":
    main()
