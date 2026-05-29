"""
Verify the Windows runner application icon matches the project's wizard icon.
"""
import os


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIZARD_ICON = os.path.join(ROOT, "assets", "icon.ico")
RUNNER_ICON = os.path.join(ROOT, "ui", "windows", "runner", "resources", "app_icon.ico")


def test_windows_runner_icon_matches_wizard_icon():
    with open(WIZARD_ICON, "rb") as f:
        wizard_bytes = f.read()
    with open(RUNNER_ICON, "rb") as f:
        runner_bytes = f.read()
    assert wizard_bytes == runner_bytes, (
        "ui/windows/runner/resources/app_icon.ico does not match assets/icon.ico — "
        "copy assets/icon.ico over the runner resources icon to fix this."
    )
