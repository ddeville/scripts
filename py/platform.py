import sys
try:
    from typing import Dict
except ImportError:
    pass  # py2

MACOS = "macos"
LINUX = "linux"
FREEBSD = "freebsd"

def get_current_platform():
    # type: () -> str
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    elif "freebsd" in sys.platform:
        return FREEBSD
    else:
        raise Exception("Platform not supported %s" % sys.platform)

def get_linux_distro_info():
    # type: () -> Dict[str, str]
    with open("/etc/os-release", "r") as f:
        return dict([entry.split("=") for entry in f.read().rstrip().split("\n")])
