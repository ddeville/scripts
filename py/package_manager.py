import subprocess
try:
    from urllib.request import urlretrieve
except ImportError:
    from urllib import urlretrieve  # type: ignore
try:
    from typing import (
        Dict,
        List,
        Union,
    )
except ImportError:
    pass  # py2

from py.platform import (
    FREEBSD,
    LINUX,
    MACOS,
    get_current_platform,
    get_linux_distro_info,
)
from py.util import (
    command_path,
    is_cmd_installed,
    run_command,
    run_command_no_output,
)

class PackageType(object):
    """An "enum" of package types."""
    DEB = "deb"
    RPM = "rpm"
    BREW = "brew"
    PACMAN = "pacman"
    PKG = "pkg"

def install_packages(packages):
    # type: (List[Union[str, Dict[PackageType, str]]]) -> None
    package_manager = create_package_manager()
    for package in packages:
        if not isinstance(package, str):
            package = package.get(package_manager.format())
        if package:
            package_manager.install_package(package)

def create_package_manager():
    # type: () -> BasePackageManager
    """Create a new package manager instance that is appropriate for the current platform."""
    plat = get_current_platform()

    if plat == MACOS:
        return BrewPackageManager()
    elif plat == LINUX:
        distro_info = get_linux_distro_info()
        distros = [distro_info.get("ID"), distro_info.get("ID_LIKE")]
        for distro in distros:
            if "debian" in distro or is_cmd_installed("apt-get"):
                return AptPackageManager()
            elif "fedora" in distro or is_cmd_installed("dnf"):
                return DnfPackageManager()
            elif "arch" in distro or is_cmd_installed("pacman"):
                return PacmanPackageManager()
    elif plat == FREEBSD:
        return PkgPackageManager()

    raise Exception("Platform not supported %s" % plat)

class BasePackageManager(object):
    """A package manager, that can be used to install packages on the current system."""

    def install(self):
        # type: () -> None
        """Install or update the package manager itself (if needed)."""
        raise NotImplementedError()

    def install_package(self, package):
        # type: (str) -> None
        """Install or update a given package."""
        raise NotImplementedError()

    def format(self):
        # type: () -> str
        """The package format, mostly for Linux."""
        raise NotImplementedError()

class BrewPackageManager(BasePackageManager):
    """The brew package manager for use on MacOS."""

    def install(self):
        # type: () -> None
        if is_cmd_installed("brew"):
            print("====> updating brew")
            run_command(["brew", "update"])
        else:
            print("====> installing brew")
            script_path, _ = urlretrieve("https://raw.githubusercontent.com/Homebrew/install/master/install")
            run_command(["/usr/bin/ruby", script_path])

    def install_package(self, package):
        # type: (str) -> None
        try:
            print("====> checking status of %s" % package)
            run_command(["brew", "ls", "--versions", package])
            # if the previous call succeeded, the package is installed so upgrade
            try:
                print("====> upgrading %s" % package)
                # NOTE: Apple Silicon support
                if "/opt/homebrew" in command_path("brew"):
                    run_command(["arch", "-arm64", "brew", "upgrade", package])
                else:
                    run_command(["brew", "upgrade", package])
            except subprocess.CalledProcessError:
                pass
        except subprocess.CalledProcessError:
            # the package has never been installed, do that now
            print("====> installing %s" % package)
            run_command(["brew", "install", package])
        run_command_no_output(["brew", "link", package])

    def format(self):
        # type: () -> str
        return PackageType.BREW

class AptPackageManager(BasePackageManager):
    """The APT package manager to use on Debian and derivatives."""

    def install(self):
        # type: () -> None
        print("====> updating apt")
        run_command(["sudo", "apt-get", "update"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "apt-get", "upgrade", "--yes", package])

    def format(self):
        # type: () -> str
        return PackageType.DEB

class DnfPackageManager(BasePackageManager):
    """The DNF package manager to use on Fedora and derivatives."""

    def install(self):
        # type: () -> None
        pass

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "dnf", "install", "--best", "--assumeyes", package])

    def format(self):
        # type: () -> str
        return PackageType.RPM

class PacmanPackageManager(BasePackageManager):
    """The Pacman package manager to use on Arch."""

    def install(self):
        # type: () -> None
        print("====> updating pacman")
        run_command(["sudo", "pacman", "-Syy"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "pacman", "-S", package])

    def format(self):
        # type: () -> str
        return PackageType.PACMAN

class PkgPackageManager(BasePackageManager):
    """The PKG package manager to use on FreeBSD."""

    def install(self):
        # type: () -> None
        print("====> updating pkg")
        run_command(["sudo", "pkg", "update"])

    def install_package(self, package):
        # type: (str) -> None
        print("====> installing %s" % package)
        run_command(["sudo", "pkg", "install", "--yes", package])

    def format(self):
        # type: () -> str
        return PackageType.PKG
