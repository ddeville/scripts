"""Read NetworkManager state without initiating a scan or changing connections."""

import json
import os
import subprocess


def nmcli(*args):
    return subprocess.check_output(
        ["nmcli", "--colors", "no", *args],
        env={**os.environ, "LC_ALL": "C"},
        text=True,
        timeout=5,
        stderr=subprocess.PIPE,
    ).strip()


def rows(fields, *args):
    # nmcli escapes both colons and backslashes in terse output.
    result = []
    for line in nmcli("--terse", "--fields", fields, *args).splitlines():
        row, field, escaped = [], "", False
        for char in line:
            if escaped:
                field += char
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == ":":
                row.append(field)
                field = ""
            else:
                field += char
        result.append(row + [field])
    return result


def status():
    devices = rows("DEVICE,TYPE,STATE,CONNECTION", "device", "status")
    wired = [
        {
            "device": device,
            "connection": connection,
            "connected": state == "connected",
            "address": nmcli("--get-values", "IP4.ADDRESS", "device", "show", device)
            if state == "connected"
            else "",
        }
        for device, kind, state, connection in devices
        if kind == "ethernet"
    ]
    wifi = [row for row in devices if row[1] == "wifi"]
    device = next(
        (row[0] for row in wifi if row[2] == "connected"), wifi[0][0] if wifi else ""
    )
    enabled = nmcli("radio", "wifi") == "enabled"
    networks = {}
    if enabled and device:
        for active, ssid, bssid, signal, security in rows(
            "IN-USE,SSID,BSSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "ifname",
            device,
            "--rescan",
            "no",
        ):
            if not ssid:
                continue
            entry = {
                "ssid": ssid,
                "bssid": bssid,
                "signal": int(signal),
                "security": security,
                "active": active == "*",
            }
            key = (ssid, security)
            previous = networks.get(key)
            if (
                previous is None
                or entry["active"]
                or (not previous["active"] and entry["signal"] > previous["signal"])
            ):
                networks[key] = entry
    networks = sorted(
        networks.values(),
        key=lambda entry: (not entry["active"], -entry["signal"], entry["ssid"]),
    )
    current = next((entry for entry in networks if entry["active"]), None)
    address = (
        nmcli("--get-values", "IP4.ADDRESS", "device", "show", device) if device else ""
    )
    return {
        "available": True,
        "enabled": enabled,
        "device": device,
        "current": current,
        "address": address,
        "networks": networks,
        "wired": wired,
    }


if __name__ == "__main__":
    try:
        print(json.dumps(status()))
    except (subprocess.SubprocessError, OSError, ValueError):
        print(
            json.dumps(
                {
                    "available": False,
                    "enabled": False,
                    "device": "",
                    "current": None,
                    "networks": [],
                    "wired": [],
                }
            )
        )
