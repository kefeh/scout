
import argparse
import hashlib
import os
import re
import sys
import time
from pathlib import Path

import adbutils
import uiautomator2 as u2

APP_PACKAGE = "com.example.flutter_scout"
TEST_LABEL = "Next"
RUNS = Path(__file__).resolve().parents[1] / "runs"


def screen_fingerprint(d) -> tuple[str, int]:
    xml = d.dump_hierarchy()
    # Strip things that change every frame without being "real" changes (e.g. a clock, progress %).
    xml = re.sub(r'text="\d{1,2}:\d{2}"', 'text=""', xml)
    clickable = len(
        re.findall(rf'package="{re.escape(APP_PACKAGE)}"[^>]*clickable="true"', xml)
    )
    return hashlib.sha1(xml.encode()).hexdigest(), clickable


def wait_until_stable(d, timeout=20, interval=0.7, needed=2) -> bool:
    """True once the tree is the same for `needed` reads in a row and has something to tap."""
    deadline = time.time() + timeout
    last, same = None, 0
    while time.time() < deadline:
        fp, clickable = screen_fingerprint(d)
        same = same + 1 if fp == last else 0
        last = fp
        if same >= needed and clickable > 0:
            return True
        time.sleep(interval)
    return False  # never settled: a stuck splash, a spinner that never ends, or an ANR


def pick_device(cli_serial: str | None) -> str:
    if cli_serial:
        return cli_serial

    if os.environ.get("ANDROID_SERIAL"):
        return os.environ["ANDROID_SERIAL"]

    devices = adbutils.adb.device_list()
    if not devices:
        sys.exit("No devices found. Run `adb connect <ip:port>` first.")

    phones: dict[str, adbutils.AdbDevice] = {}
    for dev in devices:
        real = dev.prop.get("ro.serialno") or dev.serial
        phones.setdefault(real, dev)

    if len(phones) == 1:
        return next(iter(phones.values())).serial

    choices = list(phones.items())
    for i, (real, dev) in enumerate(choices, 1):
        print(f"{i}. {dev.prop.model}  serial={real}  via {dev.serial}")
    n = int(input("Device number: "))
    return choices[n - 1][1].serial


def find_label(d, label: str, timeout=8):
    """Find an element by its visible label, whether it's in text or content-desc (Flutter)."""
    pattern = rf"(?i)^\s*{re.escape(label)}\b.*"
    for sel in (d(textMatches=pattern), d(descriptionMatches=pattern)):
        if sel.wait(timeout=timeout / 2):
            return sel
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--device", help="adb serial or ip:port (default: $ANDROID_SERIAL, or ask)"
    )
    args = parser.parse_args()

    serial = pick_device(args.device)
    d = u2.connect(serial)
    for _ in range(3):
        try:
            d.info
            break
        except Exception:
            time.sleep(2)
    else:
        sys.exit("uiautomator2 helper didn't start on the device")
    print("Connected to", d.device_info["model"], "via", serial)
    d.app_stop(APP_PACKAGE)
    # Clear the buffers right before launching so this run's files contain only this run:
    adbutils.adb.device(serial).shell("logcat -c -b main -b crash")
    d.app_start(APP_PACKAGE, wait=True)

    if not wait_until_stable(d):
        print("⚠️ screen never settled")

    run_dir = RUNS / time.strftime("%Y-%m-%dT%H-%M-%S")
    run_dir.mkdir(parents=True, exist_ok=True)
    xml = (
        d.dump_hierarchy()
    )  # the UI tree: every element with its text, id, bounds, clickable flag
    (run_dir / "tree.xml").write_text(xml)

    btn = find_label(d, TEST_LABEL)
    if btn is None:
        print(f"⚠️ '{TEST_LABEL}' not found; saving the tree for the devlog")
    else:
        btn.click()
        if not wait_until_stable(d):
            print("⚠️ screen never settled after the tap")

    dev = adbutils.adb.device(serial)
    (run_dir / "crash.txt").write_text(dev.shell("logcat -d -b crash -v time"))
    log = adbutils.adb.device(serial).shell(f"logcat -d -v time")
    (run_dir / "logcat.txt").write_text(log)
    
    (run_dir / "tree-after.xml").write_text(d.dump_hierarchy())
    d.screenshot(run_dir / "a-step1.png")

    # d.app_stop(APP_PACKAGE)


if __name__ == "__main__":
    main()
