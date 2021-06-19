import sys

from typing import Dict

MACOS = "macos"
LINUX = "linux"
FREEBSD = "freebsd"

def get_current_platform() -> str:
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    elif "freebsd" in sys.platform:
        return FREEBSD
    else:
        raise Exception("Platform not supported %s" % sys.platform)

def get_linux_distro_info() -> Dict[str, str]:
    with open("/etc/os-release", "r") as f:
        return dict([(items[0], items[1])
                     for entry in f.read().rstrip().split("\n")
                     for items in entry.split("=")])


def is_linux_distro(name: str) -> bool:
    distro_info = get_linux_distro_info()
    distros = [distro_info.get("ID"), distro_info.get("ID_LIKE")]
    for distro in distros:
        if distro and name in distro:
            return True
    return False
