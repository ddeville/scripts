#!/usr/bin/env python3

"""Read Tailscale's local state without changing connectivity or preferences."""

import json
import subprocess


def tailscale_json(*args):
    result = subprocess.run(
        ["tailscale", *args],
        capture_output=True,
        text=True,
        timeout=5,
        check=True,
    )
    return json.loads(result.stdout)


def peer_details(peer):
    location = peer.get("Location") or {}
    return {
        "id": peer.get("ID", ""),
        "name": peer.get("HostName") or peer.get("DNSName", "").rstrip("."),
        "address": next(iter(peer.get("TailscaleIPs") or []), ""),
        "online": bool(peer.get("Online")),
        "location": " · ".join(
            part for part in (location.get("Country"), location.get("City")) if part
        ),
    }


def normalize(status, profiles):
    backend = status.get("BackendState", "NoState")
    connected = backend == "Running"
    device = status.get("Self") or {}
    current = next((profile for profile in profiles if profile.get("selected")), {})
    user = (status.get("User") or {}).get(str(device.get("UserID")), {})
    peers = list((status.get("Peer") or {}).values())
    exit_status = status.get("ExitNodeStatus") or {}
    exit_peer = next(
        (peer for peer in peers if peer.get("ID") == exit_status.get("ID")), {}
    )
    exit_node = None
    if exit_status.get("ID"):
        exit_node = peer_details({**exit_peer, **exit_status})
        exit_node["name"] = exit_node["name"] or exit_node["address"] or "Exit node"

    return {
        "installed": True,
        "available": True,
        "backend": backend,
        "connected": connected,
        "account": current.get("account") or user.get("LoginName", ""),
        "tailnet": current.get("tailnet")
        or (status.get("CurrentTailnet") or {}).get("Name", ""),
        "device": device.get("HostName", ""),
        "address": next(iter(status.get("TailscaleIPs") or []), ""),
        "authUrl": status.get("AuthURL", ""),
        "exitNode": exit_node,
        "exitNodes": sorted(
            [peer_details(peer) for peer in peers if peer.get("ExitNodeOption")],
            key=lambda peer: (
                not peer["online"],
                peer["location"],
                peer["name"].lower(),
            ),
        ),
        "peers": sorted(
            [peer_details(peer) for peer in peers],
            key=lambda peer: (not peer["online"], peer["name"].lower()),
        ),
        "profiles": profiles,
        # Stopped clients can retain health warnings from the previous connection.
        "health": (status.get("Health") or []) if connected else [],
        "error": "",
    }


def read_status():
    try:
        status = tailscale_json("status", "--json")
        profiles = tailscale_json("switch", "--list", "--json")
        return normalize(status, profiles or [])
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        message = "Tailscale is unavailable"
        if isinstance(error, FileNotFoundError):
            message = "Tailscale is not installed"
        elif isinstance(error, subprocess.TimeoutExpired):
            message = "Tailscale is not responding"
        elif isinstance(error, subprocess.CalledProcessError):
            message = error.stderr.strip() or message
        return {
            "installed": not isinstance(error, FileNotFoundError),
            "available": False,
            "backend": "Unavailable",
            "connected": False,
            "account": "",
            "tailnet": "",
            "device": "",
            "address": "",
            "authUrl": "",
            "exitNode": None,
            "exitNodes": [],
            "peers": [],
            "profiles": [],
            "health": [],
            "error": message,
        }


if __name__ == "__main__":
    print(json.dumps(read_status()))
