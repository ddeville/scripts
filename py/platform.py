import sys

MACOS = "macos"
LINUX = "linux"
ALL_PLATFORMS = (MACOS, LINUX)

def get_current_platform():
    # type: () -> str
    if "darwin" in sys.platform:
        return MACOS
    elif "linux" in sys.platform:
        return LINUX
    else:
        raise Exception("Platform not supported %s" % sys.platform)
