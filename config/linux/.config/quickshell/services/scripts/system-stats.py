"""Read bar statistics directly from procfs and sysfs without subprocesses."""

import json
import time
from pathlib import Path


def read_stats(procfs=Path("/proc"), sysfs=Path("/sys")):
    with (procfs / "stat").open() as source:
        cpu = [int(value) for value in source.readline().split()[1:9]]
    memory = {
        key: int(value.split()[0])
        for key, value in (
            line.split(":", 1) for line in (procfs / "meminfo").read_text().splitlines()
        )
    }

    temperature = None
    for sensor in sorted((sysfs / "class/hwmon").glob("hwmon*/temp*_label")):
        if sensor.read_text().strip() in ("Tctl", "Package id 0"):
            reading = sensor.with_name(sensor.name.replace("_label", "_input"))
            temperature = round(int(reading.read_text()) / 1000 * 9 / 5 + 32)
            break

    backlight = None
    for device in sorted((sysfs / "class/backlight").glob("*")):
        if (device / "brightness").exists():
            backlight = (
                100
                * int((device / "brightness").read_text())
                // int((device / "max_brightness").read_text())
            )
            break

    supplies = sorted((sysfs / "class/power_supply").glob("*"))
    plugged = any(
        (device / "online").exists() and (device / "online").read_text().strip() == "1"
        for device in supplies
    )
    battery = None
    battery_status = ""
    for device in supplies:
        if (
            (device / "type").exists()
            and (device / "type").read_text().strip() == "Battery"
            and (device / "capacity").exists()
        ):
            battery = int((device / "capacity").read_text())
            battery_status = (device / "status").read_text().strip()
            break

    network = {}
    for device in sorted((sysfs / "class/net").glob("*")):
        # Count physical links once, excluding VPNs and virtual bridges.
        if not (device / "device").exists():
            continue
        if (device / "operstate").read_text().strip() != "up":
            continue
        network[device.name] = [
            int((device / "statistics" / counter).read_text())
            for counter in ("rx_bytes", "tx_bytes")
        ]

    return {
        "cpu": [sum(cpu), cpu[3] + cpu[4]],
        "memory": round(
            100 * (memory["MemTotal"] - memory["MemAvailable"]) / memory["MemTotal"]
        ),
        "temperature": temperature,
        "backlight": backlight,
        "battery": battery,
        "batteryStatus": battery_status,
        "plugged": plugged,
        "network": network,
        "uptime": float((procfs / "uptime").read_text().split()[0]),
    }


if __name__ == "__main__":
    while True:
        print(json.dumps(read_stats()), flush=True)
        time.sleep(1)
